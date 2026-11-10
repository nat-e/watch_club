defmodule WatchClub.Playbacks.Session.Actions.Play do
  @moduledoc """
  Plays the Media in the actor's active Playback Session, starting one when there is none. The
  current Playback goes on when it already plays this Media where the new one would, as when the
  Player reconnects.
  """
  use Ash.Resource.Actions.Implementation

  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.{Playback, Session}

  @impl true
  def run(
        %Ash.ActionInput{arguments: %{media_id: media_id, screen_id: screen_id}},
        _opts,
        context
      ) do
    with {:ok, session} <- active_or_new_session(context) do
      if playing?(session, media_id, screen_id) do
        {:ok, session}
      else
        session
        |> Ash.Changeset.for_update(:play_media, %{media_id: media_id, screen_id: screen_id},
          scope: context
        )
        |> Ash.update()
      end
    end
  end

  defp active_or_new_session(context) do
    case Playbacks.get_active_session(load: :current_playback, scope: context) do
      {:ok, nil} ->
        Ash.create(Session, %{}, action: :start, load: :current_playback, scope: context)

      result ->
        result
    end
  end

  # On a TV, the new Playback would play on the TV
  defp playing?(
         %Session{current_playback: %Playback{media_id: media_id}} = session,
         media_id,
         screen_id
       ),
       do: session.tv_name != nil or session.screen_id == screen_id

  defp playing?(_session, _media_id, _screen_id), do: false
end
