defmodule WatchClub.MediaSources.Import.Workers.SourceScanner do
  @moduledoc """
  Performs the scan phase of an `Import`. The source's scanner lists its files as Candidates, and
  the scan enqueues one `CandidateIngestor` job per file to process: the files without Media, and
  those whose File Stamp changed, or every file when the Import reads every file again. A Media
  saved without a File Stamp gets one, without processing its file.

  It removes the Media of the files gone: the source no longer lists them, and they're no longer on
  disk. A file the source stops listing keeps its Media while it's on disk, because Sonarr and a
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
      Ash.get!(Import, id,
        load: [media_source: [:implementation, :medias]],
        actor: SystemActor.actor()
      )

    Logger.metadata(
      read_every_file_again?: media_import.read_every_file_again?,
      source_type: source.source_type,
      source_id: source.id
    )

    candidates =
      media_import |> Scanner.for_source_type(source.source_type).scan() |> Enum.to_list()

    medias = Map.new(source.medias, &{&1.path, stamp_if_missing!(&1)})

    candidates_enqueued =
      candidates
      |> Stream.filter(fn candidate ->
        case Map.fetch(medias, candidate.path) do
          {:ok, media} ->
            media_import.read_every_file_again? or
              media.file_stamp != FileStamp.read(candidate.path, candidate.media_type)

          :error ->
            true
        end
      end)
      |> enqueue_candidates(media_import)

    remove_gone_medias!(source.medias, candidates)

    if media_import.regenerate_thumbnails_and_markers? do
      Video
      |> Ash.Query.filter(media.media_source_id == ^source.id)
      |> MediaCatalog.regenerate_thumbnails_and_markers!(
        actor: SystemActor.actor(),
        bulk_options: [strategy: [:stream]]
      )
    end

    MediaSources.finish_media_import_scan!(media_import, candidates_enqueued,
      actor: SystemActor.actor()
    )

    Logger.info("Media Import scan finished: #{candidates_enqueued} files to process",
      event: :import_scan_success,
      enqueued_candidates: candidates_enqueued
    )
  end

  # A Media saved before File Stamps existed gets its own, without processing its file
  defp stamp_if_missing!(%Media{file_stamp: nil} = media) do
    case FileStamp.read(media.path, media.type) do
      nil -> media
      stamp -> MediaCatalog.stamp_media!(media, stamp, actor: SystemActor.actor())
    end
  end

  defp stamp_if_missing!(%Media{} = media), do: media

  defp remove_gone_medias!(_medias, []), do: :ok

  defp remove_gone_medias!(medias, candidates) do
    listed = MapSet.new(candidates, & &1.path)

    for media <- medias,
        not MapSet.member?(listed, media.path),
        File.stat(media.path) == {:error, :enoent} do
      MediaCatalog.destroy_media!(media, actor: SystemActor.actor())
      Logger.info("Media deleted: #{media.path}", event: :import_media_deleted, path: media.path)
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
