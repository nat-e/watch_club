defmodule WatchClub.MediaSources.Import.Workers.CandidateIngestor do
  @moduledoc """
  Ingests a single `Candidate` into a `Media` row: runs `ExtractStructure →
  MatchContent → SaveMedia`. One Oban job per discovered candidate; enqueued
  in chunks by `WatchClub.MediaSources.Import.Workers.SourceScanner` during the scan
  phase.

  Returns `:ok` for both successful imports and explicit `{:halt, _}`
  short-circuits — halts are a clean per-file skip (unsupported file,
  missing metadata, etc.) and should not consume retry attempts. Step
  errors return `{:error, _}` so Oban retries with exponential backoff.

  Unique by `(media_import_id, path)` across active states so re-running
  the scan (manual retry, recovery) does not double-enqueue candidates.
  Tagged `media_import:<id>` so the cancel path and finalizer can find
  every candidate belonging to a Media Import.
  """

  use Oban.Worker,
    queue: :media_candidate_ingestions,
    max_attempts: 3,
    unique: [
      fields: [:worker, :args],
      keys: [:media_import_id, :path],
      states: [:available, :scheduled, :executing, :retryable],
      period: :infinity
    ]

  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Ingestor.{ExtractStructure, MatchContent, SaveMedia}
  alias WatchClub.MediaSources.Import
  alias WatchClub.SystemActor

  require Logger

  @doc """
  Builds the Oban changeset to ingest a Candidate, flattening its scan-time
  fields into the job args via `Candidate.to_map/1`.
  """
  def new_job(%Import{id: id}, %Candidate{} = candidate) do
    candidate
    |> Candidate.to_map()
    |> Map.put(:media_import_id, id)
    |> new(tags: ["media_import:#{id}"])
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_import_id" => id} = args}) do
    # The Media Import is loaded only to confirm it still exists — a cancelled
    # or deleted import should not ingest. The candidate carries its own
    # `media_type`, so the ingest stages no longer need the Media Source.
    case Ash.get(Import, id, actor: SystemActor.actor()) do
      {:ok, _media_import} ->
        args
        |> Candidate.from_map()
        |> ingest()

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:cancel, "Import #{id} not found"}
    end
  end

  defp ingest(%Candidate{} = candidate) do
    Logger.info("Ingesting candidate: #{candidate}")

    with {:ok, candidate} <- ExtractStructure.apply(candidate),
         {:ok, candidate} <- MatchContent.apply(candidate),
         {:ok, candidate} <- SaveMedia.apply(candidate) do
      Logger.info("Finished ingesting candidate: #{candidate}")
      :ok
    else
      {:halt, reason} ->
        Logger.warning("Stop ingesting candidate #{candidate}: #{inspect(reason)}")
        :ok

      {:error, _} = error ->
        error
    end
  end
end
