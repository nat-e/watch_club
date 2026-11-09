defmodule WatchClub.MediaCatalog.Workers.DetectMarkers do
  @moduledoc """
  Finds one Video's Markers. Enqueued after a Video is imported (see
  `WatchClub.MediaCatalog.Changes.ScheduleVideoProcessing`).

  A Video deleted between enqueue and run is the one expected miss and completes
  the job; anything else crashes it so Oban retries.

  Runs on a single-worker queue, because two detections must not run at once.
  """

  use Oban.Worker,
    queue: :marker_detection,
    max_attempts: 3,
    unique: [
      fields: [:worker, :args],
      keys: [:video_id],
      states: [:available, :scheduled],
      period: :infinity
    ]

  alias WatchClub.MediaCatalog
  alias WatchClub.SystemActor

  @doc "Builds a marker detection job for one Video."
  def new_job(video_id), do: new(%{video_id: video_id})

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"video_id" => video_id}}) do
    actor = SystemActor.actor()

    case MediaCatalog.get_media(video_id, not_found_error?: false, load: [:video], actor: actor) do
      # Deleted between enqueue and run — expected race, nothing to do.
      {:ok, nil} ->
        :ok

      {:ok, %{video: video}} ->
        MediaCatalog.detect_markers!(video, actor: actor)
        :ok
    end
  end
end
