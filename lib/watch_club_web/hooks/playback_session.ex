defmodule WatchClubWeb.Hooks.PlaybackSession do
  @moduledoc """
  Gives every page the User's Playback Session while it plays on a TV, as `@playback_session`,
  nil otherwise, loaded with `WatchClubWeb.Helpers.NowPlaying.fields/0`, and keeps it up to date
  for the TV bar and the Remote. `@on_tv?` only changes when it starts or stops playing on a TV,
  for what doesn't follow every position report, such as Play.

  It subscribes the page to the changes of the Playback Session, which a page can also handle
  after it, as the Player does.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

  alias Ash.Notifier.Notification
  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.Session
  alias WatchClubWeb.Helpers.NowPlaying

  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns.current_user

    {:cont,
     socket
     |> assign_playback_session(if connected?(socket), do: on_tv!(user))
     |> WatchClub.PubSub.subscribe_if_connected("playback_session:#{user.id}")
     |> attach_hook(:playback_session, :handle_info, &update!/2)}
  end

  defp on_tv!(user) do
    case Playbacks.get_active_session!(actor: user) do
      %Session{tv_name: tv_name} = session when tv_name != nil ->
        Ash.load!(session, NowPlaying.fields(), actor: user)

      _none_or_in_a_player ->
        nil
    end
  end

  # A position report changes nothing else
  defp update!(%Notification{resource: Session, action: %{name: action}, data: session}, socket) do
    current = socket.assigns.playback_session

    playback_session =
      cond do
        session.ended_at || !session.tv_name ->
          nil

        action == :heartbeat and current ->
          %{session | current_playback: current.current_playback}

        true ->
          Ash.load!(session, NowPlaying.fields(), actor: socket.assigns.current_user)
      end

    {:cont, assign_playback_session(socket, playback_session)}
  end

  defp update!(_message, socket), do: {:cont, socket}

  defp assign_playback_session(socket, playback_session) do
    socket
    |> assign(:playback_session, playback_session)
    |> assign(:on_tv?, playback_session != nil)
  end
end
