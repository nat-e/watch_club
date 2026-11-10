defmodule WatchClub.Markers.Workers.DetectMarkers do
  @moduledoc """
  Finds the Markers of the TV Show Episodes of one season, or of a single other Video.
  Enqueued after a Video is imported (see `WatchClub.Markers.Changes.ScheduleDetection`).

  A season's job waits for a minute without imports of its episodes, so an import finds
  the Markers of each season once, with all its episodes.

  Runs on a single-worker queue, so detections never take more than one core.
  """

  use Oban.Worker,
    queue: :marker_detection,
    max_attempts: 3,
    unique: [
      fields: [:worker, :args],
      keys: [:tv_show_id, :season_number, :video_id],
      states: [:available, :scheduled],
      period: :infinity
    ]

  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.{Markers, MediaCatalog}
  alias WatchClub.MediaCatalog.Video
  alias WatchClub.SystemActor

  @quiet_seconds 60

  @doc """
  Builds the job that finds the Markers of the Video, with the other episodes of its season
  when it is a TV Show Episode. Needs the Video's `tv_show_episode`.
  """
  def new_job(%Video{tv_show_episode: %TvShowEpisode{} = episode}) do
    # Pushes back the season's waiting job. `replace` only copies a time the job sets, hence
    # the explicit `scheduled_at`.
    new(%{tv_show_id: episode.tv_show_id, season_number: episode.season_number},
      scheduled_at: DateTime.add(DateTime.utc_now(), @quiet_seconds),
      replace: [scheduled: [:scheduled_at]]
    )
  end

  def new_job(%Video{tv_show_episode: nil, id: id}), do: new(%{video_id: id})

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tv_show_id" => tv_show_id, "season_number" => season_number}}) do
    Markers.detect_season_markers!(tv_show_id, season_number, actor: SystemActor.actor())
    :ok
  end

  def perform(%Oban.Job{args: %{"video_id" => video_id}}) do
    actor = SystemActor.actor()

    case MediaCatalog.get_media(video_id, not_found_error?: false, load: [:video], actor: actor) do
      # Deleted between enqueue and run — expected race, nothing to do.
      {:ok, nil} ->
        :ok

      {:ok, %{video: video}} ->
        Markers.detect_markers!(video, actor: actor)
        :ok
    end
  end
end
