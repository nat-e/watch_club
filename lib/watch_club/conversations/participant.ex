defmodule WatchClub.Conversations.Participant do
  @moduledoc """
  A User in a Conversation, and how far they have read it: the Messages after their
  `last_read_message`, by someone else, are unread for them.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Conversations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.User
  alias WatchClub.Conversations.{Conversation, Message}

  postgres do
    table "participants"
    repo WatchClub.Repo

    references do
      reference :conversation, on_delete: :delete
      reference :user, on_delete: :nilify
      reference :last_read_message, on_delete: :nilify, index?: true
    end

    # A User's Conversations
    custom_indexes do
      index [:user_id]
    end
  end

  actions do
    defaults [:read]

    create :create do
      description "Recommend Content adds the Participants when it starts a Conversation"
      accept [:conversation_id, :user_id]
    end

    update :mark_read do
      description "Marks every Message of the Conversation read for this Participant"
      change atomic_update(:last_read_message_id, expr(latest_message_id))
    end
  end

  policies do
    policy actor_absent() do
      description "Conversations are only for signed-in Users"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Participants see who else is in their Conversations"
      authorize_if can_read(:conversation)
    end

    policy action(:mark_read) do
      description "A User marks only their own Conversations read"
      authorize_if relates_to_actor_via(:user)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # The User's pages subscribe to the new Conversation. The metadata says its Content.
    publish :create, ["user", :user_id],
      load: [conversation: [:content_id]],
      transform: &add_content_id_to_metadata/1

    # The User's other pages update their unread counts
    publish :mark_read, ["user", :user_id]

    defp add_content_id_to_metadata(%Ash.Notifier.Notification{} = notification) do
      content_id = notification.data.conversation.content_id
      %{notification | metadata: Map.put(notification.metadata, :content_id, content_id)}
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :conversation, Conversation, allow_nil?: false

    # Nil once that User is deleted: they keep their place in the Conversation
    belongs_to :user, User

    # Nil until they open the Conversation: every Message is unread
    belongs_to :last_read_message, Message
  end

  aggregates do
    # As `unread?/2`. Message ids follow the time they're posted.
    count :unread_count, [:conversation, :messages] do
      filter expr(
               (is_nil(parent(last_read_message_id)) or id > parent(last_read_message_id)) and
                 is_distinct_from(author_id, parent(user_id))
             )
    end

    first :latest_message_id, [:conversation, :messages], :id do
      sort id: :desc
    end
  end

  identities do
    identity :user_in_conversation, [:conversation_id, :user_id] do
      message dgettext_noop("errors", "This person is already in the conversation")
    end
  end

  @doc """
  Whether a Message is unread for the Participant: posted after the one they read last, by someone
  else. As the `unread_count` aggregate.
  """
  def unread?(%__MODULE__{} = participant, %Message{} = message) do
    message.author_id != participant.user_id and
      (participant.last_read_message_id == nil or message.id > participant.last_read_message_id)
  end
end
