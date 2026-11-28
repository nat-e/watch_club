defmodule WatchClub.MediaSources.Import.Workers.SourceScanner do
  @moduledoc """
  Performs the scan phase of an `Import`. The source's scanner lists its files as Candidates, and
  the scan enqueues one `CandidateIngestor` job per file to process: the files without Media, and
  those whose File Stamp changed, or every file when the Import reads every file again. A Media
  saved without a File Stamp gets one, without processing its file.

  It removes the Media of the files gone: the source no longer lists them, and they're no longer on
  disk. A file it can't read keeps its Media as it is. A file the source stops listing keeps its Media while it's on disk, because Sonarr and a
  folder walk skip what they fail to read. A source that lists no file removes nothing, as when its
  folder can't be reached.

  With `regenerate_thumbnails_and_markers?`, it rebuilds them for every Video of the source.

  The Candidate discovery logic depends on the type of source (Filesystem, Servarr...).
  See the `WatchClub.MediaSources.Import.Scanner` module for details.
  """

  use Oban.Worker, queue: :media_source_scans, max_attempts: 1

  alias WatchClub.MediaCatalog
  alias WatchClub.MediaCatalog.{Media, Video}
  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.{Import, Source}
  alias WatchClub.MediaSources.Import.FileStamp
  alias WatchClub.MediaSources.Import.Scanner
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor
  alias WatchClub.SystemActor

  require Ash.Query
  require Logger

  @chunk_size 1_000

  @doc """
  Builds the Oban changeset for a `Import`. Callers go through this
  helper so the args contract and tag scheme stay in one place.
  """
  def new_job(%Import{id: id}) do
    new(
      %{media_import_id: id},
      tags: ["media_import:#{id}"]
    )
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_import_id" => id}}) do
    Logger.metadata(media_import_id: id)

    %Import{media_source: %Source{} = source} =
      media_import =
      Ash.get!(Import, id, load: [media_source: [:implementation]], actor: SystemActor.actor())

    Logger.metadata(
      read_every_file_again?: media_import.read_every_file_again?,
      source_type: source.source_type,
      source_id: source.id
    )

    candidates =
      media_import |> Scanner.for_source_type(source.source_type).scan() |> Enum.to_list()

    # Loaded once the source has listed its files, which can take minutes, so that the Media
    # webhooks moved or removed meanwhile are seen as they are now
    medias =
      Media
      |> Ash.Query.filter(media_source_id == ^source.id)
      |> Ash.Query.select([:id, :path, :type, :file_stamp])
      |> Ash.read!(actor: SystemActor.actor())
      |> Map.new(&{&1.path, stamp_if_missing!(&1)})

    remove_gone_medias!(source, medias, candidates)

    if media_import.regenerate_thumbnails_and_markers? do
      Video
      |> Ash.Query.filter(media.media_source_id == ^source.id)
      |> MediaCatalog.regenerate_thumbnails_and_markers!(
        actor: SystemActor.actor(),
        bulk_options: [strategy: [:stream]]
      )
    end

    candidates_enqueued =
      candidates
      |> Stream.filter(&to_process?(&1, Map.get(medias, &1.path), media_import))
      |> enqueue_candidates(media_import)

    MediaSources.finish_media_import_scan!(media_import, candidates_enqueued,
      actor: SystemActor.actor()
    )

    Logger.info("Media Import scan finished: #{candidates_enqueued} files to process",
      event: :import_scan_success,
      enqueued_candidates: candidates_enqueued
    )
  end

  defp to_process?(_candidate, nil, _media_import), do: true
  defp to_process?(_candidate, _media, %Import{read_every_file_again?: true}), do: true

  # A file it can't read now keeps its Media as it is
  defp to_process?(candidate, media, _media_import) do
    stamp = FileStamp.read(candidate.path, candidate.media_type)
    stamp != nil and stamp != media.file_stamp
  end

  # A Media without a File Stamp gets one, without processing its file
  defp stamp_if_missing!(%Media{file_stamp: nil} = media) do
    case FileStamp.read(media.path, media.type) do
      nil -> media
      stamp -> MediaCatalog.stamp_media!(media, stamp, actor: SystemActor.actor())
    end
  end

  defp stamp_if_missing!(%Media{} = media), do: media

  defp remove_gone_medias!(_source, _medias, []), do: :ok

  defp remove_gone_medias!(source, medias, candidates) do
    listed = MapSet.new(candidates, & &1.path)

    gone_paths =
      for {path, _media} <- medias,
          not MapSet.member?(listed, path),
          File.stat(path) == {:error, :enoent},
          do: path

    if gone_paths != [] do
      Logger.info("Removing the Media of #{length(gone_paths)} files gone",
        event: :import_media_deleted,
        paths: gone_paths
      )

      # By path, so a Media that a webhook moved or removed since is left alone
      Media
      |> Ash.Query.filter(media_source_id == ^source.id and path in ^gone_paths)
      |> MediaCatalog.destroy_media!(
        actor: SystemActor.actor(),
        bulk_options: [strategy: [:stream], notify?: true]
      )
    end

    :ok
  end

  defp enqueue_candidates(candidates, %Import{} = media_import) do
    candidates
    |> Stream.chunk_every(@chunk_size)
    |> Enum.reduce(0, fn chunk, acc ->
      chunk
      |> Enum.map(&CandidateIngestor.new_job(media_import, &1))
      |> OpentelemetryOban.insert_all()

      acc + length(chunk)
    end)
  end
end
