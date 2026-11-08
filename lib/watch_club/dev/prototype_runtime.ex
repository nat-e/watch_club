defmodule WatchClub.Dev.PrototypeRuntime do
  @moduledoc "Compiles prototype code on demand, separately from Mix and app startup."
  use GenServer

  @table __MODULE__

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def load(prototype), do: GenServer.call(__MODULE__, {:load, prototype}, 40_000)

  def status(slug) do
    case :ets.lookup(@table, slug) do
      [{^slug, status}] -> status
      [] -> %{state: :unopened, diagnostics: []}
    end
  end

  def statuses, do: @table |> :ets.tab2list() |> Map.new()

  def forget(slug), do: GenServer.cast(__MODULE__, {:forget, slug})

  def failed(slug, error), do: GenServer.cast(__MODULE__, {:failed, slug, error})

  @impl true
  def init(state) do
    :ets.new(@table, [:named_table, :protected, read_concurrency: true])
    {:ok, state}
  end

  @impl true
  def handle_call({:load, %{error: error}}, _from, state) when not is_nil(error),
    do: {:reply, {:error, error}, state}

  def handle_call({:load, prototype}, _from, state) do
    files = Enum.sort(prototype.files ++ prototype.shared_files)
    fingerprint = Enum.map(files, &{&1, :crypto.hash(:sha256, File.read!(&1))})

    case state[prototype.slug] do
      %{fingerprint: ^fingerprint, modules: modules} ->
        :ets.insert(@table, {prototype.slug, %{state: :ready, diagnostics: []}})
        {:reply, {:ok, modules}, state}

      _ ->
        task =
          Task.Supervisor.async_nolink(WatchClub.Shared.Fs.TaskSupervisor, fn ->
            compile_prototype(Enum.filter(files, &(Path.extname(&1) == ".ex")))
          end)

        case Task.yield(task, 30_000) || Task.shutdown(task, :brutal_kill) do
          {:ok, {:ok, modules, warnings}} ->
            diagnostics = warnings.compile_warnings ++ warnings.runtime_warnings
            :ets.insert(@table, {prototype.slug, %{state: :ready, diagnostics: diagnostics}})

            {:reply, {:ok, modules},
             Map.put(state, prototype.slug, %{fingerprint: fingerprint, modules: modules})}

          {:ok, {:error, errors, _warnings}} ->
            error = Enum.map_join(errors, "\n\n", &diagnostic/1)
            :ets.insert(@table, {prototype.slug, %{state: :error, diagnostics: [error]}})
            {:reply, {:error, error}, state}

          other ->
            error =
              case other do
                {:exit, reason} -> Exception.format_exit(reason)
                nil -> "Prototype compilation took longer than 30 seconds"
              end

            :ets.insert(@table, {prototype.slug, %{state: :error, diagnostics: [error]}})
            {:reply, {:error, error}, state}
        end
    end
  rescue
    exception ->
      error = Exception.format(:error, exception, __STACKTRACE__)
      :ets.insert(@table, {prototype.slug, %{state: :error, diagnostics: [error]}})
      {:reply, {:error, error}, state}
  end

  @impl true
  def handle_cast({:forget, slug}, state) do
    :ets.delete(@table, slug)
    {:noreply, Map.delete(state, slug)}
  end

  def handle_cast({:failed, slug, error}, state) do
    :ets.insert(@table, {slug, %{state: :error, diagnostics: [error]}})
    {:noreply, state}
  end

  defp diagnostic(%{message: message} = diagnostic) do
    file = diagnostic[:file] || "prototype"

    position =
      case diagnostic[:position] do
        {line, column} -> "#{line}:#{column}"
        line when is_integer(line) -> to_string(line)
        _ -> ""
      end

    "#{file}:#{position}\n#{message}"
  end

  defp compile_prototype(files) do
    bundled_asset =
      Enum.find(files, fn file ->
        Regex.scan(~r/<(?:script|style)\b([^>]*)>/s, File.read!(file), capture: :all_but_first)
        |> Enum.any?(fn [attributes] ->
          String.contains?(attributes, ":type") and
            not Regex.match?(~r/(?:^|\s)runtime(?:\s|=|$)/, attributes)
        end)
      end)

    if bundled_asset do
      {:error,
       [
         %{
           file: bundled_asset,
           message:
             "Prototype assets must stay outside the app bundle. Use ColocatedHook with the runtime attribute and a hook object without export default; use plain inline styles for CSS."
         }
       ], %{}}
    else
      Kernel.ParallelCompiler.compile(files, return_diagnostics: true)
    end
  end
end
