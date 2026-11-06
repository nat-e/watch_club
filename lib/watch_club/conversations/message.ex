defmodule WatchClub.Conversations.Message do
  @moduledoc """
  Something a Participant posts in a Conversation: the recommendation that starts it, or text.
  Messages are never edited or deleted, and their ids follow the time they're posted.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Conversations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.User
  alias WatchClub.Conversations.{Conversation, MessageKind}
  alias WatchClub.Conversations.Message.Changes.MarkConversationReadForAuthor

  postgres do
    table "messages"
    repo WatchClub.Repo

    references do
      reference :conversation, on_delete: :delete
      reference :author, on_delete: :nilify
    end

    # A Conversation's Messages, in order, and the unread ones after a read position
    custom_indexes do
      index [:conversation_id, :id]
    end
  end

  actions do
    defaults [:read]

    create :recommendation do
      description "The recommendation that starts a Conversation, from the actor"
      accept [:conversation_id, :body]

      change set_attribute(:kind, :recommendation)
      change relate_actor(:author)
    end

    create :post do
      description "A Participant posts text in their Conversation, which they have then read"
      accept [:conversation_id, :body]

      validate present(:body) do
        message dgettext_noop("errors", "Write a message")
      end

      change set_attribute(:kind, :text)
      change relate_actor(:author)
      change MarkConversationReadForAuthor
    end
  end

  policies do
    policy actor_absent() do
      description "Conversations are only for signed-in Users"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Only the Participants of its Conversation see a Message"
      authorize_if expr(exists(conversation.participants, user_id == ^actor(:id)))
    end

    policy action(:post) do
      description "Only a Participant can post in a Conversation"
      authorize_if expr(exists(conversation.participants, user_id == ^actor(:id)))
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish :post, ["conversation", :conversation_id]
  end

  validations do
    validate string_length(:body, max: 2000) do
      message dgettext_noop("errors", "The message cannot be longer than %{max} characters")
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :kind, MessageKind do
      allow_nil? false
      public? true
    end

    # Nil on a recommendation sent without text
    attribute :body, :string do
      public? true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :conversation, Conversation, allow_nil?: false

    # Nil once that User is deleted: the Message stays
    belongs_to :author, User do
      attribute_writable? false
    end
  end
end
