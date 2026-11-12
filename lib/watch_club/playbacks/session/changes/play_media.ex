defmodule WatchClub.Playbacks.Session.Changes.PlayMedia do
  @moduledoc """
  Ends the current Playback and starts one for the `media_id` argument, on the `screen_id`
  Screen, or on the TV when the Playback Session plays there. Expects the Playback Session locked.

  It resumes where the actor stopped in this Video, unless they finished it. Otherwise it starts
  from the beginning.
  """
  use Ash.Resource.Change

  alias WatchClub.MediaCatalog.{Part, Video}
  alias WatchClub.Playbacks.Playback
  alias WatchClub.Playbacks.Session.Changes.EndCurrentPlayback

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(
      changeset,
      &play!(&1, Ash.Changeset.get_argument(&1, :media_id), context)
    )
  end

  @doc "In a `before_action`: plays the Media in the Playback Session the changeset updates."
  def play!(changeset, media_id, context) do
    EndCurrentPlayback.end_current_playback!(changeset.data, context)

    case Ash.create(Playback, %{session_id: changeset.data.id, media_id: media_id},
           load: [
             media: [
               video: [
                 parts: [
                   movie: :actor_progress,
                   tv_show_episode: :actor_progress,
                   sports_event: :actor_progress
                 ]
               ]
             ]
           ],
           scope: context
         ) do
      {:ok, playback} ->
        Ash.Changeset.force_change_attributes(changeset, %{
          screen_id:
            if(changeset.data.tv_name,
              do: changeset.data.screen_id,
              else: Ash.Changeset.get_argument(changeset, :screen_id)
            ),
          position_seconds: resume_position(playback.media.video),
          paused?: false,
          last_heartbeat_at: DateTime.utc_now()
        })

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  # The position in this Video's Part, if the actor stopped there and hasn't finished
  defp resume_position(%Video{parts: [part | _]}) do
    case Part.work(part).actor_progress do
      %{completed: false, part_number: number, part_position_seconds: seconds}
      when number == part.number and is_float(seconds) ->
        seconds

      _not_started_finished_or_elsewhere ->
        0.0
    end
  end

  defp resume_position(%Video{parts: []}), do: 0.0
end
