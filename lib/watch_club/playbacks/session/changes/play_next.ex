defmodule WatchClub.Playbacks.Session.Changes.PlayNext do
  @moduledoc """
  Plays what follows the current Video on the same Screen: the next Part of the same work, else
  the next TV Show Episode if it has Media. When nothing follows, the Playback Session ends.

  Expects the Playback Session locked. Fails with a stale record error when the `playback_id`
  argument isn't the current Playback anymore, so a late report changes nothing.
  """
  use Ash.Resource.Change

  alias WatchClub.Playbacks.Session
  alias WatchClub.Playbacks.Session.Changes.{EndCurrentPlayback, PlayMedia}

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      %{current_playback: playback} =
        Ash.load!(
          changeset.data,
          [current_playback: [media: [video: :next_to_play]]],
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

        next = playback.media.video.next_to_play ->
          PlayMedia.play!(changeset, next.video.id, context)

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
end
