defmodule WatchClub.Markers.Changes.ScheduleDetection do
  @moduledoc """
  Schedules Marker detection for a saved Video: for the season of its TV Show Episode, or for its
  Movie. Use it as a change on Video actions.

  It schedules only when the file is new, its File Fingerprint changed or its Parts changed, or
  always with `always?: true`. Unmatched Media and Sports Events get no Markers. The job is
  inserted in the action's transaction, so it runs once the Video is saved.
  """

  use Ash.Resource.Change

  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.Markers.Workers.DetectMarkers
  alias WatchClub.MediaCatalog.Part

  @impl true
  def change(changeset, opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, video ->
      if Keyword.get(opts, :always?, false) or changeset.context[:parts_changed?] or
           Ash.Changeset.changing_attribute?(changeset, :file_fingerprint) do
        # A file holding several TV Show Episodes holds episodes of one season
        case Ash.load!(video, [parts: [:tv_show_episode]], scope: context).parts do
          [%Part{tv_show_episode: %TvShowEpisode{} = episode} | _] ->
            OpentelemetryOban.insert!(
              DetectMarkers.new_season_job(episode.tv_show_id, episode.season_number)
            )

          [%Part{movie_id: movie_id} | _] when is_binary(movie_id) ->
            OpentelemetryOban.insert!(DetectMarkers.new_movie_job(movie_id))

          _unmatched_or_sports_event ->
            :none
        end
      end

      {:ok, video}
    end)
  end
end
