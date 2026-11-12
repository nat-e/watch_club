defmodule WatchClub.MediaSources.Import.Workers.CandidateIngestor do
  @moduledoc """
  Ingests a single `Candidate` into a `Media` row of its Media Source via `ExtractStructure →
  MatchContent → SaveMedia`. Two entry points share this worker and queue:

    * `new_job(%Import{}, candidate)` — scan candidates, tagged `media_import:<id>`, default
      priority.
    * `new_job(%Servarr{}, candidate)` — a single file from a Radarr/Sonarr `Download` webhook
      (no Media Import), higher priority so live events preempt a running
      scan.

  Each run ends with the file's outcome: `matched`, `unmatched`, or `unreadable` when ffprobe
  can't read it, which saves no Media. It reports the outcome, with a reason, in one log line,
  in its trace span and in a `[:watch_club, :media_ingest]` telemetry span. An exception makes
  Oban retry with backoff.

  Unique on `(media_source_id, media_import_id, path)` over active states; webhook jobs have no
  `media_import_id` and dedupe by Media Source and `path`.
  """

  use Oban.Worker,
    queue: :media_candidate_ingestions,
    max_attempts: 3,
    unique: [
      fields: [:worker, :args],
      keys: [:media_source_id, :media_import_id, :path],
      states: :incomplete,
      period: :infinity
    ]

  alias OpenTelemetry.Tracer
  alias WatchClub.MediaSources.{Import, Servarr}
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MatchResult
  alias WatchClub.MediaSources.Import.Ingestor.{ExtractStructure, MatchContent, SaveMedia}

  require Logger

  @doc """
  Builds an ingest job into the Media Source of the Media Import or the webhook's Servarr app.
  A scan `Candidate` is tagged with its Media Import, at default priority, and carries its choice
  to regenerate Scrubbing Thumbnails and Markers. A webhook `Candidate` has no Media Import, and a
  higher priority than scan jobs.
  """
  def new_job(%Import{id: id} = media_import, %Candidate{} = candidate) do
    %{
      candidate
      | media_source_id: media_import.media_source_id,
        regenerate_thumbnails_and_markers?: media_import.regenerate_thumbnails_and_markers?
    }
    |> Candidate.to_map()
    |> Map.put(:media_import_id, id)
    |> new(tags: ["media_import:#{id}"], priority: 1)
  end

  def new_job(%Servarr{id: media_source_id}, %Candidate{} = candidate) do
    %{candidate | media_source_id: media_source_id}
    |> Candidate.to_map()
    |> new(priority: 0)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    candidate = Candidate.from_map(args)
    media_import_id = args["media_import_id"]

    Logger.metadata(
      path: candidate.path,
      media_type: candidate.media_type,
      media_import_id: media_import_id
    )

    start_metadata = %{
      media_type: candidate.media_type,
      trigger: if(media_import_id, do: :media_import, else: :webhook)
    }

    :telemetry.span([:watch_club, :media_ingest], start_metadata, fn ->
      {outcome, reason} = ingest(candidate)

      Tracer.set_attributes(%{
        "file.path" => candidate.path,
        "watch_club.media.type" => to_string(candidate.media_type),
        "watch_club.media_ingest.outcome" => to_string(outcome),
        "watch_club.media_ingest.reason" => to_string(reason)
      })

      {:ok, Map.merge(start_metadata, %{outcome: outcome, reason: reason})}
    end)
  end

  # Ingests the file and logs its outcome, returned as `{outcome, reason}`
  defp ingest(%Candidate{path: path} = candidate) do
    case ExtractStructure.apply(candidate) do
      {:ok, candidate} ->
        %Candidate{match_result: %MatchResult{result: result, reason: reason}} =
          candidate = MatchContent.apply!(candidate)

        SaveMedia.apply(candidate)

        {level, message} =
          case {result, reason} do
            {:matched, :manual_match} ->
              {:info, "#{path} keeps its Manual Match"}

            {:matched, nil} ->
              {:info, "Matched #{path}"}

            {:unmatched, :content_not_found} ->
              {:warning, "No Content matches #{path}"}

            {:unmatched, :episode_not_listed} ->
              {:warning, "TMDB doesn't list the TV Show Episode of #{path}"}
          end

        Logger.log(level, message,
          event: :media_ingested,
          outcome: result,
          reason: reason,
          tmdb_id: get_in(candidate.identity, [Access.key(:tmdb_id)])
        )

        {result, reason}

      {:error, error} ->
        Logger.warning("Couldn't read #{path}: #{inspect(error)}",
          event: :media_ingested,
          outcome: :unreadable,
          error: error
        )

        {:unreadable, nil}
    end
  end
end
