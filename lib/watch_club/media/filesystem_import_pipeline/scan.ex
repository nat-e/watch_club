defmodule WatchClub.Media.ImportPipeline.Scan do
  @moduledoc false

  alias WatchClub.Media.ImportPipeline.Candidate
  alias WatchClub.Media.ImportPipeline.Scan.{IgnoreRules, MediaTypeFilter}
  alias WatchClub.Media.MediaSource
  alias WatchClub.Shared.Fs

  require Logger

  # Allow more time for the first operation for slow booting external drives
  @initial_disk_operation_timeout 15_000

  @doc """
  Returns a lazy `Stream` of `Candidate` values produced by walking the
  configured filesystem path.

  `skip_paths` is a `MapSet` of expanded paths that should be skipped without
  even running an `lstat` — typically the paths of media already imported
  for this `MediaSource`. Pass `MapSet.new/0` to scan everything.

  The root path is checked eagerly: this function returns `{:error, _}` if
  the root is missing, inaccessible, a symlink, or not a directory. Once the
  root gate passes, all subsequent per-path errors during the walk are
  logged and the offending path/subtree is dropped — the stream never
  raises in normal operation.
  """
  def stream_candidate_files(media_source, skip_paths \\ MapSet.new())

  def stream_candidate_files(
        %MediaSource{source_type: :filesystem, filesystem_path: root_path} = media_source,
        skip_paths
      ) do
    root_path = Path.expand(root_path)

    case Fs.lstat(root_path, time: :posix, timeout: @initial_disk_operation_timeout) do
      {:ok, %{type: :directory}} ->
        {:ok, candidate_stream(root_path, media_source, skip_paths)}

      {:ok, %{type: :symlink}} ->
        {:error, "Media Source filesystem location cannot be a symbolic link: #{root_path}"}

      {:ok, %{type: type}} ->
        {:error, "Media Source filesystem location is not a directory: #{root_path} (#{type})"}

      {:error, reason} ->
        {:error,
         "Cannot access Media Source filesystem location #{root_path}: #{inspect(reason)}"}
    end
  end

  def stream_candidate_files(%MediaSource{source_type: source_type}, _skip_paths) do
    {:error, "Unsupported Media Source Type: #{inspect(source_type)}"}
  end

  defp candidate_stream(root_path, media_source, skip_paths) do
    Stream.resource(
      fn -> [root_path] end,
      fn
        [] ->
          {:halt, []}

        [path | rest] ->
          case inspect_path(Path.expand(path), root_path, media_source, skip_paths) do
            :drop -> {[], rest}
            {:enqueue, children} -> {[], children ++ rest}
            {:emit, candidate} -> {[candidate], rest}
          end
      end,
      fn _ -> :ok end
    )
  end

  defp inspect_path(path, root_path, media_source, skip_paths) do
    if MapSet.member?(skip_paths, path) do
      Logger.debug("Skipping file #{path} (media already exist)")
      :drop
    else
      inspect_unseen_path(path, root_path, media_source)
    end
  end

  defp inspect_unseen_path(path, root_path, media_source) do
    Logger.debug("Scanning file #{path}")

    case Fs.lstat(path, time: :posix) do
      {:ok, %{type: :symlink}} ->
        :drop

      {:ok, %{type: :directory}} ->
        if IgnoreRules.directory_ignored?(path, root_path) do
          :drop
        else
          {:enqueue, children(path)}
        end

      {:ok, %{type: :regular}} ->
        if IgnoreRules.file_ignored?(path, root_path) or
             not MediaTypeFilter.accepted?(path, media_source) do
          Logger.debug("Skipping file #{path} (ignored)")
          :drop
        else
          {:emit, Candidate.new(path)}
        end

      {:ok, _} ->
        Logger.debug("Skipping file #{path} (unsupported type)")
        :drop

      {:error, :timeout} ->
        Logger.warning("Filesystem lstat timed out, skipping: #{path}")
        :drop

      {:error, reason} ->
        Logger.warning("Cannot inspect filesystem path, skipping #{path} (#{inspect(reason)})")
        :drop
    end
  end

  defp children(path) do
    case Fs.ls(path) do
      {:ok, entries} ->
        entries
        |> Enum.sort()
        |> Enum.map(&Path.join(path, &1))

      {:error, :timeout} ->
        Logger.warning("Filesystem ls timed out, skipping subtree: #{path}")
        []

      {:error, reason} ->
        Logger.warning(
          "Cannot list filesystem directory, skipping subtree #{path} (#{inspect(reason)})"
        )

        []
    end
  end
end
