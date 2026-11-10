defmodule WatchClub.Markers.Changes.ScheduleDetection do
  @moduledoc """
  Enqueues the `DetectMarkers` job of the Video's TV Show Episode's season, or of its Movie, when
  its file is new, its File Fingerprint changed or its match changed. With `always?: true`, every
  time. Unmatched Media gets no Markers.

  The job is inserted in the action's transaction, so it runs once the Video is saved.
  """

  use Ash.Resource.Change

  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.Markers.Workers.DetectMarkers
  alias WatchClub.MediaCatalog.Video

  @impl true
  def change(changeset, opts, context) do
    Ash.Changeset.after_action(changeset, fn changeset, video ->
      if Keyword.get(opts, :always?, false) or
           Enum.any?(
             [:file_fingerprint, :movie_id, :tv_show_episode_id],
             &Ash.Changeset.changing_attribute?(changeset, &1)
           ) do
        case Ash.load!(video, :tv_show_episode, scope: context) do
          %Video{tv_show_episode: %TvShowEpisode{} = episode} ->
            OpentelemetryOban.insert!(
              DetectMarkers.new_season_job(episode.tv_show_id, episode.season_number)
            )

          %Video{movie_id: movie_id} when is_binary(movie_id) ->
            OpentelemetryOban.insert!(DetectMarkers.new_movie_job(movie_id))

          %Video{} ->
            :unmatched
        end
      end

      {:ok, video}
    end)
  end
end
