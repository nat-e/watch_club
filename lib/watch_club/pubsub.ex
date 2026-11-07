defmodule WatchClub.PubSub do
  @moduledoc """
  Helpers and topics for the WatchClub PubSub notification service
  """
  alias WatchClub.Accounts.User

  @doc """
  Subscribes a LiveView socket to a topic or list of PubSub topics if the socket is connected
  """
  def subscribe_if_connected(socket, topics) do
    if Phoenix.LiveView.connected?(socket) do
      topics |> List.wrap() |> Enum.each(&Phoenix.PubSub.subscribe(__MODULE__, &1))
    end

    socket
  end

  # Subscribes to the PubSub topics for Content-related notifications
  # for the current user.
  def subscribe_to_current_user_content_topics(socket) do
    if Phoenix.LiveView.connected?(socket) do
      content_topics(socket.assigns.current_user)
      |> List.wrap()
      |> Enum.each(&Phoenix.PubSub.subscribe(__MODULE__, &1))
    end

    socket
  end

  @doc """
  Subscribes a LiveView socket to the topic of each Playlist it loaded, once. It stays subscribed
  to the Playlists it no longer loads: their notifications only make it reload.
  """
  def subscribe_to_playlists(socket, playlists) do
    subscribed = socket.assigns[:subscribed_playlist_ids] || MapSet.new()
    new_ids = playlists |> MapSet.new(& &1.id) |> MapSet.difference(subscribed)

    socket
    |> subscribe_if_connected(Enum.map(new_ids, &"playlist:#{&1}"))
    |> Phoenix.Component.assign(:subscribed_playlist_ids, MapSet.union(subscribed, new_ids))
  end

  defp content_topics(%User{} = user) do
    ["content:global", "content:user:#{user.id}"]
  end
end
