defmodule WatchClub.Requests.RequestSubscriber do
  @moduledoc """
  A `User` told when a `ContentRequest` becomes playable: the one who made it, and everyone who
  chose Get Notified on it, until they Stop Getting Notified. Each User sees only their own.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Requests,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

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

      # So that finding it by its Content Request finds the actor's own
      change filter(expr(user_id == ^actor(:id)))
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
