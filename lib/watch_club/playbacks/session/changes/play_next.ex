defmodule WatchClub.Playbacks.Session.Changes.PlayNext do
  @moduledoc """
  Plays the TV Show Episode after the current one when it has Media, on the same Screen.
  Otherwise, nothing follows: the Playback Session ends. Expects the Playback Session locked.
  Fails when the `playback_id` argument is no longer the current Playback: it finished late.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.TvShowEpisode
  alias WatchClub.Playbacks.Session
  alias WatchClub.Playbacks.Session.Changes.{EndCurrentPlayback, PlayMedia}

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      %{current_playback: playback} =
        Ash.load!(
          changeset.data,
          [current_playback: [media: [video: [tv_show_episode: [next_episode: :videos]]]]],
          scope: context
        )

      cond do
        # Also once the Playback Session ended
        is_nil(playback) or playback.id != Ash.Changeset.get_argument(changeset, :playback_id) ->
          Ash.Changeset.add_error(
            changeset,
            Ash.Error.Changes.StaleRecord.exception(
              resource: Session,
              filter: %{current_playback_id: Ash.Changeset.get_argument(changeset, :playback_id)}
            )
          )

        next_video = next_video(playback.media.video.tv_show_episode) ->
          PlayMedia.play!(changeset, next_video.id, context)

        true ->
          EndCurrentPlayback.end_current_playback!(changeset.data, context)

          changeset
          |> Ash.Changeset.force_change_attribute(:ended_at, DateTime.utc_now())
          |> Ash.Changeset.after_action(fn _changeset, session ->
            :telemetry.execute([:watch_club, :playback_session, :end], %{count: 1}, %{
              reason: :nothing_next
            })

            {:ok, session}
          end)
      end
    end)
  end

  defp next_video(%TvShowEpisode{next_episode: %TvShowEpisode{videos: [video | _]}}), do: video
  defp next_video(_movie_or_last_episode), do: nil
end
