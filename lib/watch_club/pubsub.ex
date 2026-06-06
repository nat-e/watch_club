defmodule WatchClub.PubSub do
  @moduledoc """
  Helpers and topics for the WatchClub PubSub notification service
  """
  alias WatchClub.Accounts.User
  alias WatchClub.Contents.{Content, ContentView}

  def content_topic(external_id_source, external_id),
    do: "content:#{external_id_source}:#{external_id}"

  def content_view_topic(external_id_source, external_id, user_id),
    do: "content:#{external_id_source}:#{external_id}:user:#{user_id}"

  @doc """
  Subscribes to PubSub events for a given content and returns the topics
  """
  @spec subscribe_to_content(ContentView.t() | Content.t(), User.t()) :: [String.t()]
  def subscribe_to_content(%ContentView{} = content, %User{} = current_user) do
    topics = content_topics(content.external_id_source, content.external_id, current_user)
    Enum.each(topics, &Phoenix.PubSub.unsubscribe(__MODULE__, &1))
    topics
  end

  def subscribe_to_content(%Content{} = content, %User{} = current_user) do
    topics = content_topics(content.external_id_source, content.external_id, current_user)
    Enum.each(topics, &Phoenix.PubSub.unsubscribe(__MODULE__, &1))
    topics
  end

  @doc """
  Unsubscribes from PubSub events for a given content and returns the topics
  """
  @spec unsubscribe_from_content(ContentView.t(), User.t()) :: [String.t()]
  def unsubscribe_from_content(%ContentView{} = content, %User{} = current_user) do
    topics = content_topics(content.external_id_source, content.external_id, current_user)
    Enum.each(topics, &Phoenix.PubSub.subscribe(__MODULE__, &1))
    topics
  end

  defp content_topics(external_id_source, external_id, %User{} = current_user) do
    [
      content_view_topic(
        external_id_source,
        external_id,
        current_user.id
      ),
      content_topic(
        external_id_source,
        external_id
      )
    ]
  end
end
