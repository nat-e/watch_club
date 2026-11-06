defmodule WatchClub.Requests.RequestSubscriber do
  @moduledoc """
  A `User` told when a `ContentRequest` becomes playable: the one who made it, and everyone who
  chose Get Notified on it, until they Stop Getting Notified. Each User sees only their own.

  It's ready unseen from when its Content Request becomes playable until the User opens My
  Requests, and the Requests tab's badge counts it meanwhile.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Requests,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  require Ash.Query

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.ContentIdentity
  alias WatchClub.Requests.ContentRequest

  postgres do
    table "request_subscribers"
    repo WatchClub.Repo

    references do
      reference :content_request, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :create do
      description "Get Notified: the actor becomes a Request Subscriber. Doing it again changes nothing."
      primary? true
      upsert? true
      upsert_identity :unique_request_and_user
      upsert_fields []

      accept [:content_request_id]

      change relate_actor(:user)
    end

    destroy :destroy do
      description "Stop Getting Notified: the actor stops being a Request Subscriber."
      primary? true

      # Found by its Content Request, so only the actor's own: the read policy would forbid
      # other Users' rows, not skip them
      change filter(expr(user_id == ^actor(:id)))
    end

    update :mark_ready_unseen do
      description "Its Content Request just became playable."
      accept []
      change set_attribute(:ready_unseen?, true)
    end

    update :mark_ready_seen do
      accept []
      change set_attribute(:ready_unseen?, false)
    end

    action :mark_all_ready_seen do
      description "The actor opened My Requests: none of theirs is ready unseen anymore."

      run fn _input, context ->
        __MODULE__
        |> Ash.Query.filter(user_id == ^context.actor.id and ready_unseen?)
        |> Ash.bulk_update!(:mark_ready_seen, %{}, Ash.Context.to_opts(context, notify?: true))

        :ok
      end
    end
  end

  policies do
    policy actor_absent() do
      description "Request Subscriber actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:create) do
      authorize_if relating_to_actor(:user)
    end

    policy action_type([:read, :destroy]) do
      description "Each User sees, and stops, only their own"
      authorize_if relates_to_actor_via(:user)
    end

    policy action(:mark_ready_unseen) do
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action(:mark_ready_seen) do
      description "Each User sees their own"
      authorize_if relates_to_actor_via(:user)
    end

    policy action(:mark_all_ready_seen) do
      description "It marks only the actor's own"
      authorize_if always()
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # Publish to the User's content topic, with :content_id and :content_identity in the
    # metadata so that subscribers know which Content it's about
    publish_all :create, ["content", "user", :user_id],
      load: [content_request: [content: [:type, :external_id_source, :external_id]]],
      transform: &add_content_identity_to_metadata/1

    publish_all :destroy, ["content", "user", :user_id],
      load: [content_request: [content: [:type, :external_id_source, :external_id]]],
      transform: &add_content_identity_to_metadata/1

    # The User's topic, so that every page updates the Requests tab's badge
    publish_all :update, ["user", :user_id]

    defp add_content_identity_to_metadata(%Ash.Notifier.Notification{} = notification) do
      content = notification.data.content_request.content

      %{
        notification
        | metadata:
            notification.metadata
            |> Map.put(:content_identity, ContentIdentity.from_content(content))
            |> Map.put(:content_id, content.id)
      }
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :ready_unseen?, :boolean do
      allow_nil? false
      default false
      source :is_ready_unseen
    end

    timestamps()
  end

  relationships do
    belongs_to :content_request, ContentRequest do
      allow_nil? false
    end

    belongs_to :user, User do
      allow_nil? false
      attribute_writable? false
    end
  end

  identities do
    identity :unique_request_and_user, [:content_request_id, :user_id]
  end
end
