defmodule WatchClub.Markers.Changes.ScheduleDetection do
  @moduledoc """
  After a Video upsert commits, enqueues the `DetectMarkers` job of its TV Show Episode's
  season, or of its Movie. Unmatched Media gets no Markers.
  """

  use Ash.Resource.Change

  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.Markers.Workers.DetectMarkers
  alias WatchClub.MediaCatalog.Video

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, media} <- result do
        case Ash.load!(media, [video: :tv_show_episode], scope: context).video do
          %Video{tv_show_episode: %TvShowEpisode{} = episode} ->
            OpentelemetryOban.insert!(
              DetectMarkers.new_season_job(episode.tv_show_id, episode.season_number)
            )

          %Video{movie_id: movie_id} when is_binary(movie_id) ->
            OpentelemetryOban.insert!(DetectMarkers.new_movie_job(movie_id))

          %Video{} ->
            :unmatched
        end

        {:ok, media}
      end
    end)
  end
end
