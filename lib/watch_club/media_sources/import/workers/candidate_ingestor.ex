defmodule WatchClub.MediaSources.Import.Workers.CandidateIngestor do
  @moduledoc """
  Ingests a single `Candidate` into a `Media` row via `ExtractStructure →
  MatchContent → SaveMedia`. Two entry points share this worker and queue:

    * `new_job/2` — scan candidates, tagged `media_import:<id>`, default
      priority.
    * `new_job/1` — a single file from a Radarr/Sonarr `Download` webhook
      (no Media Import), higher priority so live events preempt a running
      scan.

  `:ok` on success and on `{:halt, _}` (clean per-file skip, no retry);
  `{:error, _}` so Oban retries with backoff. Unique on `(media_import_id,
  path)` over active states; webhook jobs have no `media_import_id` and
  dedupe by `path`.
  """

  use Oban.Worker,
    queue: :media_candidate_ingestions,
    max_attempts: 3,
    unique: [
      fields: [:worker, :args],
      keys: [:media_import_id, :path],
      states: :incomplete,
      period: :infinity
    ]

  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Ingestor.{ExtractStructure, MatchContent, SaveMedia}
  alias WatchClub.MediaSources.Import

  require Logger

  @doc "Builds an ingest job for a scan `Candidate`, tagged with the import at default priority."
  def new_job(%Import{id: id}, %Candidate{} = candidate) do
    candidate
    |> Candidate.to_map()
    |> Map.put(:media_import_id, id)
    |> new(tags: ["media_import:#{id}"], priority: 1)
  end

  @doc "Builds an ingest job for a webhook `Candidate` (no Media Import), at higher priority than scan jobs."
  def new_job(%Candidate{} = candidate) do
    candidate
    |> Candidate.to_map()
    |> new(priority: 0)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    args
    |> Candidate.from_map()
    |> ingest()
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
