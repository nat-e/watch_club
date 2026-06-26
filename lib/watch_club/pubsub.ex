defmodule WatchClub.PubSub do
  @moduledoc """
  Helpers and topics for the WatchClub PubSub notification service
  """
  alias WatchClub.Accounts.User
  alias WatchClub.Contents.ContentIdentity

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

  def subscribe_to_content_activity_feed(socket, %ContentIdentity{
        external_id_source: source,
        external_id: id
      }) do
    subscribe_if_connected(socket, "feed:content:#{source}:#{id}")
  end

  defp content_topics(%User{} = user) do
    Enum.map(user.memberships, &"content:club:#{&1.club_id}") ++
      ["content:global", "content:user:#{user.id}"]
  end
end
