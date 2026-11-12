defmodule WatchClub.MediaSources.Import.Workers.SourceScanner do
  @moduledoc """
  Performs the scan phase of an `Import`.
  It will create a list of import Candidates for the source and enqueue
  one CandiateIngestor job per eligible candidate.

  The Import's `files_to_process` decides which Candidates that already have Media in the source
  are skipped: all of them (`:new`, the default), the matched ones (`:new_and_unmatched`) or none
  (`:all`).

  The actual Candidate discovery logic depends on the type of source (Filesystem, Servarr...).
  See the `WatchClub.MediaSources.Import.Scanner` module for details.
  """

  use Oban.Worker, queue: :media_source_scans, max_attempts: 1

  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.{Import, Source}

  alias WatchClub.MediaSources.Import.Scanner
  alias WatchClub.MediaSources.Import.Workers.CandidateIngestor
  alias WatchClub.SystemActor

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

    %Import{media_source: %Source{}} =
      import_job =
      Import
      |> Ash.get!(id, load: [media_source: [:implementation]], actor: SystemActor.actor())

    Logger.metadata(
      files_to_process: import_job.files_to_process,
      source_type: import_job.media_source.source_type,
      source_id: import_job.media_source.id
    )

    scanner = Scanner.for_source_type(import_job.media_source.source_type)
    to_skip = paths_to_skip(import_job)

    candidates_enqueued =
      import_job
      |> scanner.scan()
      |> Stream.reject(fn candidate ->
        skip? = MapSet.member?(to_skip, candidate.path)
        if skip?, do: Logger.debug("Skipping candidate, already imported")
        skip?
      end)
      |> enqueue_candidates(import_job)

    MediaSources.finish_media_import_scan!(import_job, candidates_enqueued,
      actor: SystemActor.actor()
    )

    Logger.info("Media Import scan finished: #{candidates_enqueued} files to process",
      event: :import_scan_success,
      enqueued_candidates: candidates_enqueued
    )
  end

  defp paths_to_skip(%Import{files_to_process: :all}), do: MapSet.new()

  defp paths_to_skip(%Import{files_to_process: files_to_process, media_source: source}) do
    source
    |> Ash.load!(:medias, actor: SystemActor.actor())
    |> Map.fetch!(:medias)
    |> Enum.reject(&(files_to_process == :new_and_unmatched and is_nil(&1.content_id)))
    |> MapSet.new(& &1.path)
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
