defmodule WatchClub.Media.Importer.FilesystemDiscovery do
  @moduledoc false

  alias WatchClub.Media.Importer.{IgnoreRules, MediaCandidate, MediaTypeFilter}
  alias WatchClub.Media.MediaImportConfiguration

  defmodule Error do
    defexception [:message]
  end

  def stream(
        %MediaImportConfiguration{source_type: :filesystem, filesystem_path: root_path} =
          configuration
      ) do
    root_path = Path.expand(root_path)

    case File.lstat(root_path, time: :posix) do
      {:ok, %{type: :directory}} ->
        {:ok, walk(root_path, configuration)}

      {:ok, %{type: :symlink}} ->
        {:error, "Media Import filesystem location cannot be a symbolic link: #{root_path}"}

      {:ok, %{type: type}} ->
        {:error, "Media Import filesystem location is not a directory: #{root_path} (#{type})"}

      {:error, reason} ->
        {:error,
         "Cannot access Media Import filesystem location #{root_path}: #{inspect(reason)}"}
    end
  end

  def stream(%MediaImportConfiguration{source_type: source_type}) do
    {:error, "Unsupported Media Import Source Type: #{inspect(source_type)}"}
  end

  defp walk(root_path, configuration) do
    Stream.resource(
      fn -> [root_path] end,
      fn
        [] ->
          {:halt, []}

        [path | rest] ->
          path
          |> Path.expand()
          |> next_path(root_path, rest, configuration)
      end,
      fn _state -> :ok end
    )
  end

  defp next_path(path, root_path, rest, configuration) do
    case File.lstat(path, time: :posix) do
      {:ok, %{type: :symlink}} ->
        {[], rest}

      {:ok, %{type: :directory} = stat} ->
        if IgnoreRules.ignored?(path, root_path, stat.type) do
          {[], rest}
        else
          {[], children(path) ++ rest}
        end

      {:ok, %{type: :regular} = stat} ->
        if IgnoreRules.ignored?(path, root_path, stat.type) or
             not MediaTypeFilter.accepted?(path, configuration) do
          {[], rest}
        else
          {[MediaCandidate.new(path, root_path, stat, configuration)], rest}
        end

      {:ok, _stat} ->
        {[], rest}

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
