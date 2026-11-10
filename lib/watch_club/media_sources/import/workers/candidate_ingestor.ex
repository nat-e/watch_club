defmodule WatchClub.MediaSources.Import.Workers.CandidateIngestor do
  @moduledoc """
  Ingests a single `Candidate` into a `Media` row of its Media Source via `ExtractStructure →
  MatchContent → SaveMedia`. Two entry points share this worker and queue:

    * `new_job(%Import{}, candidate)` — scan candidates, tagged `media_import:<id>`, default
      priority.
    * `new_job(%Servarr{}, candidate)` — a single file from a Radarr/Sonarr `Download` webhook
      (no Media Import), higher priority so live events preempt a running
      scan.

  `:ok` on success and when `ExtractStructure` skips the file (no retry); an
  exception makes Oban retry with backoff. Unique on `(media_source_id, media_import_id, path)`
  over active states; webhook jobs have no `media_import_id` and dedupe by
  Media Source and `path`.
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

  alias WatchClub.MediaSources.{Import, Servarr}
  alias WatchClub.MediaSources.Import.Candidate
  alias WatchClub.MediaSources.Import.Ingestor.{ExtractStructure, MatchContent, SaveMedia}

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
    Logger.metadata(path: args["path"], media_type: args["media_type"])

    args
    |> Candidate.from_map()
    |> ingest()
  end

  defp ingest(%Candidate{} = candidate) do
    with {:ok, candidate} <- ExtractStructure.apply(candidate),
         candidate <- MatchContent.apply!(candidate),
         _candidate <- SaveMedia.apply(candidate) do
      :ok
    else
      :skip ->
        :ok
    end
  end
end
