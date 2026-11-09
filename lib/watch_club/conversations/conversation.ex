defmodule WatchClub.Conversations.Conversation do
  @moduledoc """
  The Messages about one Content between the User who recommended it and the Users they
  recommended it to, its Participants. Recommend Content starts one, and its Participants never
  change.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Conversations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.Changes.EnsureContentExists
  alias WatchClub.Contents.{Content, ContentIdentity}
  alias WatchClub.Conversations.Conversation.Changes.StartConversation
  alias WatchClub.Conversations.{Message, Participant}

  postgres do
    table "conversations"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete
      reference :recommended_by, on_delete: :nilify, index?: true
    end

    # The Conversations about a Content
    custom_indexes do
      index [:content_id]
    end
  end

  actions do
    defaults [:read]

    read :latest_first do
      description "The actor's Conversations, the one with the latest Message first"

      argument :content_id, :uuid do
        description "Keeps the Conversations about this Content"
      end

      argument :unread?, :boolean do
        allow_nil? false
        default false
        description "Keeps the Conversations with Messages the actor hasn't read"
      end

      prepare build(filter: expr(content_id == ^arg(:content_id))), where: present(:content_id)

      prepare build(
                filter: expr(exists(participants, user_id == ^actor(:id) and unread_count > 0))
              ),
              where: argument_equals(:unread?, true)

      prepare build(sort: [last_message_at: :desc])
    end

    create :recommend do
      description "Starts a Conversation between the actor and the Users they recommend the Content to, with the recommendation as its first Message"

      argument :content_identity, ContentIdentity, allow_nil?: false

      argument :recipient_ids, {:array, :uuid_v7} do
        # The validation below owns the user-facing message
        allow_nil? false
        default []
      end

      argument :body, :string, description: "The text sent with the recommendation"

      validate argument_does_not_equal(:recipient_ids, []) do
        message dgettext_noop("errors", "Choose at least one person")
      end

      validate string_length(:body, max: 2000) do
        message dgettext_noop("errors", "The message cannot be longer than %{max} characters")
      end

      change relate_actor(:recommended_by)
      change EnsureContentExists
      change StartConversation
    end
  end

  policies do
    policy actor_absent() do
      description "Conversations are only for signed-in Users"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Only its Participants see a Conversation"
      authorize_if expr(exists(participants, user_id == ^actor(:id)))
    end

    policy action(:recommend) do
      description "Any User can Recommend Content"
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :content, Content do
      allow_nil? false
      # Set by EnsureContentExists from the content_identity argument
      attribute_writable? false
    end

    # Nil once that User is deleted
    belongs_to :recommended_by, User do
      attribute_writable? false
    end

    has_many :participants, Participant

    # Who it was recommended to. Deleted Users are left out once the recommender is deleted too.
    has_many :recipients, Participant do
      filter expr(is_distinct_from(user_id, parent(recommended_by_id)))
    end

    has_many :messages, Message do
      sort id: :asc
    end

    has_one :recommendation, Message do
      filter expr(kind == :recommendation)
    end

    has_one :last_message, Message do
      from_many? true
      sort id: :desc
    end

    has_one :actor_participant, Participant do
      filter expr(user_id == ^actor(:id))
    end
  end

  aggregates do
    max :last_message_at, :messages, :inserted_at
  end
end
