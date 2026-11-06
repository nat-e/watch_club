defmodule WatchClub.Conversations.Participant do
  @moduledoc """
  A User in a Conversation, and how far they have read it: the Messages after their
  `last_read_message` are unread for them.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Conversations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.User
  alias WatchClub.Conversations.{Conversation, Message}

  postgres do
    table "participants"
    repo WatchClub.Repo

    references do
      reference :conversation, on_delete: :delete
      reference :user, on_delete: :nilify
      reference :last_read_message, on_delete: :nilify
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
      accept [:conversation_id, :user_id, :last_read_message_id]
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
      authorize_if expr(exists(conversation.participants, user_id == ^actor(:id)))
    end

    policy action(:mark_read) do
      description "A User marks only their own Conversations read"
      authorize_if relates_to_actor_via(:user)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # The User's pages subscribe to the new Conversation
    publish :create, ["user", :user_id]
    # The User's other pages update their unread counts
    publish :mark_read, ["user", :user_id]
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
    # Message ids follow the time they're posted
    count :unread_count, [:conversation, :messages] do
      filter expr(is_nil(parent(last_read_message_id)) or id > parent(last_read_message_id))
    end

    first :latest_message_id, [:conversation, :messages], :id do
      sort id: :desc
    end
  end

  identities do
    identity :user_in_conversation, [:conversation_id, :user_id]
  end
end
