defmodule WatchClub.Playbacks.Session.Changes.RecordWatchProgress do
  @moduledoc """
  Records the actor's Watch Progress for the current Playback from the heartbeat's
  reported position.

  Upserts the progress of each Movie, TV Show Episode or Sports Event the Playback's Video holds a
  Part of, marking it completed once playback passes 90% of the Video up to its Credits. No-op for
  Media without Content.
  """
  use Ash.Resource.Change

  alias WatchClub.History
  alias WatchClub.MediaCatalog.Media

  @impl true
  def change(changeset, _opts, context) do
    position = Ash.Changeset.get_argument(changeset, :position_seconds)

    Ash.Changeset.after_action(changeset, fn _changeset, session ->
      %Media{id: media_id, video: video} =
        Ash.load!(session, [current_playback: [media: [video: [:credits_start_seconds, :parts]]]],
          scope: context
        ).current_playback.media

      # Progress counts up to the Credits, so playing the next episode from there completes it
      duration = video.credits_start_seconds || video.duration_seconds

      progress = %{
        last_media_id: media_id,
        position_seconds: if(duration, do: min(position, duration), else: position),
        duration_seconds: duration
      }

      for part <- video.parts do
        progress
        |> Map.merge(Map.take(part, [:movie_id, :tv_show_episode_id, :sports_event_id]))
        |> History.record_watch_progress!(scope: context)
      end

      {:ok, session}
    end)
  end
end
