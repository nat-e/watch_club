defmodule WatchClub.MediaSources.Import.Scanner.Filesystem.Scan do
  @moduledoc false

  alias WatchClub.MediaSources.{Filesystem, Source}
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Scanner.Filesystem.Scan.{IgnoreRules, MediaTypeFilter}
  alias WatchClub.Shared.Fs
  alias WatchClub.Shared.Path, as: Paths

  require Logger

  # Allow more time for the first operation for slow booting external drives
  @initial_disk_operation_timeout 15_000

  @doc """
  Returns a lazy `Stream` of `Candidate` values produced by walking the
  configured filesystem path.

  The root path is checked eagerly and this function raises if the root is
  missing, inaccessible, a symlink, or not a directory — a misconfigured
  Media Source is fatal and the import job should crash. Once the root gate
  passes, per-path errors during the walk are logged and the offending
  path/subtree is dropped — the stream never raises in normal operation.
  """
  def stream_candidate_files!(
        %Source{
          source_type: :filesystem,
          implementation: %Filesystem{filesystem_path: root_path}
        } = media_source
      ) do
    root_path = Paths.normalize(root_path)

    case Fs.lstat(root_path, time: :posix, timeout: @initial_disk_operation_timeout) do
      {:ok, %{type: :directory}} ->
        candidate_stream(root_path, media_source)
    end
  end

  defp candidate_stream(root_path, media_source) do
    Stream.resource(
      fn -> [root_path] end,
      fn
        [] ->
          {:halt, []}

        [path | rest] ->
          case inspect_path(Paths.normalize(path), root_path, media_source) do
            :drop -> {[], rest}
            {:enqueue, children} -> {[], children ++ rest}
            {:emit, candidate} -> {[candidate], rest}
          end
      end,
      fn _ -> :ok end
    )
  end

  defp inspect_path(path, root_path, media_source) do
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
          {:emit, Candidate.new(path, media_source.media_type)}
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
