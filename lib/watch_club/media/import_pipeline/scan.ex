defmodule WatchClub.Media.ImportPipeline.Scan do
  @moduledoc false

  alias WatchClub.Media.ImportConfiguration
  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Scan.{IgnoreRules, MediaTypeFilter}

  defmodule Error do
    defexception [:message]
  end

  def list_candidate_files(
        %ImportConfiguration{source_type: :filesystem, filesystem_path: root_path} = configuration
      ) do
    root_path = Path.expand(root_path)

    case File.lstat(root_path, time: :posix) do
      {:ok, %{type: :directory}} ->
        {:ok, walk([root_path], root_path, configuration, [])}

      {:ok, %{type: :symlink}} ->
        {:error, "Media Import filesystem location cannot be a symbolic link: #{root_path}"}

      {:ok, %{type: type}} ->
        {:error, "Media Import filesystem location is not a directory: #{root_path} (#{type})"}

      {:error, reason} ->
        {:error,
         "Cannot access Media Import filesystem location #{root_path}: #{inspect(reason)}"}
    end
  end

  def list_candidate_files(%ImportConfiguration{source_type: source_type}) do
    {:error, "Unsupported Media Import Source Type: #{inspect(source_type)}"}
  end

  defp walk([], _root_path, _configuration, candidates), do: Enum.reverse(candidates)

  defp walk([path | rest], root_path, configuration, candidates) do
    expanded = Path.expand(path)

    case inspect_path(expanded, root_path, configuration) do
      :drop -> walk(rest, root_path, configuration, candidates)
      {:enqueue, children} -> walk(children ++ rest, root_path, configuration, candidates)
      {:emit, candidate} -> walk(rest, root_path, configuration, [candidate | candidates])
    end
  end

  defp inspect_path(path, root_path, configuration) do
    case File.lstat(path, time: :posix) do
      {:ok, %{type: :symlink}} ->
        :drop

      {:ok, %{type: :directory} = stat} ->
        if IgnoreRules.ignored?(path, root_path, stat.type) do
          :drop
        else
          {:enqueue, children(path)}
        end

      {:ok, %{type: :regular} = stat} ->
        if IgnoreRules.ignored?(path, root_path, stat.type) or
             not MediaTypeFilter.accepted?(path, configuration) do
          :drop
        else
          {:emit, Candidate.new(path, root_path, stat)}
        end

      {:ok, _stat} ->
        :drop

      {:error, reason} ->
        raise Error, message: "Cannot inspect filesystem path #{path}: #{inspect(reason)}"
    end
  end

  defp children(path) do
    case File.ls(path) do
      {:ok, entries} ->
        entries
        |> Enum.sort()
        |> Enum.map(&Path.join(path, &1))

      {:error, reason} ->
        raise Error, message: "Cannot list filesystem directory #{path}: #{inspect(reason)}"
    end
  end
end
