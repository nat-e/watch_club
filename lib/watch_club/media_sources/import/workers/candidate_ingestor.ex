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
  can't read it or its Keyframes, which saves no Media. It counts the file on its Media Import, and emits the
  outcome, with a reason, in a `[:watch_club, :media_ingest]` telemetry span, which
  `IngestReporter` logs and `WatchClubWeb.Telemetry` measures. A crash is the `failed` outcome:
  Oban retries it with backoff, and the last attempt counts the file as failed.

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

  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.{Import, Servarr}
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Candidate.MatchResult
  alias WatchClub.MediaSources.Import.Ingestor.{ExtractStructure, MatchContent, SaveMedia}
  alias WatchClub.SystemActor

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
  def perform(%Oban.Job{args: args} = job) do
    # From the job's arguments, so a Candidate that can't be built is reported too
    metadata = %{
      path: args["path"],
      media_type: args["media_type"],
      trigger: if(args["media_import_id"], do: :media_import, else: :webhook)
    }

    Logger.metadata([media_import_id: args["media_import_id"]] ++ Map.to_list(metadata))

    :telemetry.span([:watch_club, :media_ingest], metadata, fn ->
      {:ok, Map.merge(metadata, ingest_and_count!(job))}
    end)
  end

  # Ingests the file and counts its outcome on its Media Import. Oban retries a crash, and the
  # last one counts the file as failed.
  defp ingest_and_count!(%Oban.Job{args: args} = job) do
    media_import_id = args["media_import_id"]

    outcome =
      try do
        args |> Candidate.from_map() |> ingest()
      catch
        kind, reason ->
          if job.attempt >= job.max_attempts, do: count_file!(media_import_id, :failed)
          :erlang.raise(kind, reason, __STACKTRACE__)
      end

    count_file!(media_import_id, outcome.outcome)
    outcome
  end

  # The file's outcome, its reason, and what explains it
  defp ingest(%Candidate{} = candidate) do
    case ExtractStructure.apply(candidate) do
      {:ok, candidate} ->
        %Candidate{match_result: %MatchResult{result: result, reason: reason}} =
          candidate = MatchContent.apply!(candidate)

        SaveMedia.apply!(candidate)

        %{
          outcome: result,
          reason: reason,
          tmdb_id: get_in(candidate.identity, [Access.key(:tmdb_id)])
        }

      {:error, error} ->
        %{outcome: :unreadable, reason: nil, error: error}
    end
  end

  # A webhook's file has no Media Import
  defp count_file!(nil, _outcome), do: :ok

  defp count_file!(media_import_id, outcome) do
    media_import_id
    |> MediaSources.get_media_import_by_id!(actor: SystemActor.actor())
    |> MediaSources.count_media_import_file!(outcome, actor: SystemActor.actor())
  end
end
