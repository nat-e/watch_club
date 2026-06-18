defmodule WatchClub.Playbacks.Session.Changes.UpdateWatchProgress do
  @moduledoc """
  Records the actor's Watch Progress for this Playback from the heartbeat's
  reported position.

  Resolves the Playback's Media to its Movie or TV Show Episode and upserts the
  per-unit progress, marking it completed once playback passes 90% of the
  Video's duration. No-op when the heartbeat carried no position.
  """
  use Ash.Resource.Change

  alias WatchClub.History
  alias WatchClub.MediaCatalog.{Media, Video}

  @impl true
  def change(changeset, _opts, context) do
    case Ash.Changeset.get_argument(changeset, :position_seconds) do
      nil ->
        changeset

      position ->
        Ash.Changeset.after_action(changeset, fn _changeset, playback ->
          %Media{id: media_id, video: video} =
            Ash.load!(playback, [media: :video], scope: context).media

          record_progress(video, media_id, position, context)
          {:ok, playback}
        end)
    end
  end

  defp record_progress(%Video{movie_id: movie_id} = video, media_id, position, context)
       when not is_nil(movie_id) do
    History.record_movie_progress!(
      %{
        movie_id: movie_id,
        last_media_id: media_id,
        position_seconds: position,
        duration_seconds: video.duration_seconds
      },
      scope: context
    )
  end

  defp record_progress(
         %Video{tv_show_episode_id: episode_id} = video,
         media_id,
         position,
         context
       )
       when not is_nil(episode_id) do
    History.record_episode_progress!(
      %{
        tv_show_episode_id: episode_id,
        last_media_id: media_id,
        position_seconds: position,
        duration_seconds: video.duration_seconds
      },
      scope: context
    )
  end
end
