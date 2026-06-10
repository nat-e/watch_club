defmodule WatchClub.MediaCatalog.Workers.GenerateTrickplay do
  @moduledoc """
  Builds the sprite-sheet JPEGs and generation metadata for one Video's
  scrubbing thumbnails. Enqueued after a Video is imported (see
  `WatchClub.MediaCatalog.Changes.ScheduleTrickplay`). The WebVTT manifest the
  player loads is built at serve time from that metadata (see
  `WatchClub.Ffmpeg.Trickplay`).

  Each run wipes and rebuilds the Video's trickplay directory, so a re-imported
  Video always reflects its current file.

  A Video deleted between enqueue and run is the one expected miss and completes
  the job; anything else crashes it so Oban retries.

  Runs on a single-worker queue so generation never crowds out imports or
  on-demand transcodes.
  """

  use Oban.Worker,
    queue: :trickplay_generation,
    max_attempts: 3,
    unique: [
      fields: [:worker, :args],
      keys: [:video_id],
      states: [:available, :scheduled],
      period: :infinity
    ]

  alias WatchClub.Ffmpeg.Trickplay
  alias WatchClub.MediaCatalog
  alias WatchClub.MediaCatalog.VideoTrack
  alias WatchClub.SystemActor

  @doc "Builds a trickplay generation job for one Video."
  def new_job(video_id), do: new(%{video_id: video_id})

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"video_id" => video_id}}) do
    case MediaCatalog.get_media(video_id,
           not_found_error?: false,
           load: [video: :default_video_track],
           actor: SystemActor.actor()
         ) do
      # Deleted between enqueue and run — expected race, nothing to do.
      {:ok, nil} ->
        :ok

      {:ok,
       %{
         path: source_path,
         video: %{duration_seconds: duration, default_video_track: %VideoTrack{} = track}
       }} ->
        Trickplay.generate_sprites(video_id, source_path, track, duration)
    end
  end
end
