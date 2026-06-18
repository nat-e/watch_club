defmodule WatchClub.Contents.Notifiers.ContentChangedNotifier do
  @moduledoc """
  Custom Ash.Notifier for sending PubSub notifications when a Content or its view for a user
  change.

  The notification carries everything in `metadata`, so this module does no
  resolution. `recipients` is either `:global` (the shared content topic) or a
  list of user ids (each user's content-view topic).
  """
  use Ash.Notifier

  alias Ash.Notifier.Notification
  alias WatchClub.Contents.ContentIdentity

  @doc """
  Builds a `:content_changed` notification for `content`, scoped to `recipients`
  (`:global` or a list of user ids).

  `for: [__MODULE__]` keeps it from reaching other notifiers declared on the
  resource (e.g. `Ash.Notifier.PubSub`).
  """
  @spec create_notification(
          Ash.Resource.t(),
          Ash.Resource.Actions.action(),
          WatchClub.Contents.Content.t(),
          :global | [Ash.UUID.t()],
          Ash.Resource.record() | nil
        ) :: Notification.t()
  def create_notification(resource, action, content, recipients, actor) do
    Notification.new(resource,
      action: action,
      data: content,
      actor: actor,
      for: [__MODULE__],
      metadata: %{
        subject: :content_changed,
        content_id: content.id,
        content_identity: ContentIdentity.from_content(content),
        recipients: recipients
      }
    )
  end

  @impl true
  def notify(%Notification{metadata: %{subject: :content_changed} = metadata} = notification) do
    %{content_identity: identity, recipients: recipients} = metadata

    case recipients do
      :global ->
        broadcast(
          WatchClub.PubSub.content_topic(identity.external_id_source, identity.external_id),
          notification
        )

      user_ids ->
        Enum.each(user_ids, fn user_id ->
          broadcast(
            WatchClub.PubSub.content_view_topic(
              identity.external_id_source,
              identity.external_id,
              user_id
            ),
            notification
          )
        end)
    end
  end

  def notify(_notification), do: :ok

  defp broadcast(topic, notification) do
    Phoenix.PubSub.broadcast(WatchClub.PubSub, topic, %Phoenix.Socket.Broadcast{
      topic: topic,
      event: "content_changed",
      payload: notification
    })
  end
end
