defmodule WatchClub.Markers.Workers.DetectMarkers do
  @moduledoc """
  Finds the Markers of the TV Show Episodes of a season, or of a Movie's Videos. Enqueued
  after a Video is imported (see `WatchClub.Markers.Changes.ScheduleDetection`).

  Each import of one of a season's episodes pushes its waiting job back to a minute later,
  until the job is due. The job reads the season when it starts, so an import usually finds
  the Markers of each season once, with all its episodes.

  Runs on a single-worker queue, so detections never take more than one core.
  """

  use Oban.Worker,
    queue: :marker_detection,
    max_attempts: 3,
    unique: [
      fields: [:worker, :args],
      keys: [:tv_show_id, :season_number, :movie_id],
      states: [:available, :scheduled],
      period: :infinity
    ]

  alias WatchClub.Markers
  alias WatchClub.SystemActor

  @quiet_seconds 60

  @doc "Builds the job that finds the Markers of a season's TV Show Episodes, in a minute."
  def new_season_job(tv_show_id, season_number) do
    # Pushes back the season's waiting job. `replace` only copies a time the job sets, hence
    # the explicit `scheduled_at`.
    new(%{tv_show_id: tv_show_id, season_number: season_number},
      scheduled_at: DateTime.add(DateTime.utc_now(), @quiet_seconds),
      replace: [scheduled: [:scheduled_at]]
    )
  end

  @doc "Builds the job that finds the Markers of a Movie's Videos."
  def new_movie_job(movie_id), do: new(%{movie_id: movie_id})

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tv_show_id" => tv_show_id, "season_number" => season_number}}) do
    Markers.detect_season_markers!(tv_show_id, season_number, actor: SystemActor.actor())
    :ok
  end

  def perform(%Oban.Job{args: %{"movie_id" => movie_id}}) do
    Markers.detect_movie_markers!(movie_id, actor: SystemActor.actor())
    :ok
  end
end
