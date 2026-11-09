defmodule WatchClub.Contents.MetadataFetcher do
  @moduledoc false
  use GenServer

  alias WatchClub.Contents
  alias WatchClub.Contents.{ContentIdentity, MetadataUnavailable}
  alias WatchClub.SystemActor

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, nil, Keyword.put(opts, :name, __MODULE__))

  @doc "Creates or refreshes Content, sharing an in-flight fetch with every caller for its identity."
  @spec fetch(ContentIdentity.t()) :: {:ok, WatchClub.Contents.Content.t()} | {:error, term()}
  def fetch(identity) do
    case GenServer.call(__MODULE__, {:fetch, identity}, :infinity) do
      {:exit, reason} -> exit(reason)
      result -> result
    end
  end

  @impl true
  def init(nil), do: {:ok, %{}}

  @impl true
  def handle_call({:fetch, identity}, from, fetches) do
    fetch =
      case Map.get(fetches, identity) do
        nil ->
          task =
            Task.Supervisor.async_nolink(__MODULE__.TaskSupervisor, fn ->
              fetch_content(identity)
            end)

          %{task: task, callers: [from]}

        fetch ->
          %{fetch | callers: [from | fetch.callers]}
      end

    {:noreply, Map.put(fetches, identity, fetch)}
  end

  @impl true
  def handle_info({ref, result}, fetches) do
    {identity, fetch} = Enum.find(fetches, fn {_identity, fetch} -> fetch.task.ref == ref end)
    Process.demonitor(ref, [:flush])
    Enum.each(fetch.callers, &GenServer.reply(&1, result))
    {:noreply, Map.delete(fetches, identity)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, fetches) do
    {identity, fetch} = Enum.find(fetches, fn {_identity, fetch} -> fetch.task.ref == ref end)
    Enum.each(fetch.callers, &GenServer.reply(&1, {:exit, reason}))
    {:noreply, Map.delete(fetches, identity)}
  end

  defp fetch_content(identity) do
    content =
      Contents.get_content_by_identity!(identity,
        not_found_error?: false,
        actor: SystemActor.actor()
      )

    result =
      if content,
        do: Contents.refresh_metadata(content, %{}, actor: SystemActor.actor()),
        else: Contents.create_content(identity, actor: SystemActor.actor())

    case result do
      {:ok, refreshed} ->
        {:ok, refreshed}

      {:error, error} ->
        if Enum.any?(error.errors, &match?(%MetadataUnavailable{}, &1)) do
          if content, do: {:ok, content}, else: {:error, error}
        else
          raise error
        end
    end
  end
end
