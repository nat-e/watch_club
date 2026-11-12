defmodule WatchClub.History.HiddenFromHome do
  @moduledoc """
  A Content a User hid from Home: it leaves their Content in progress until a new Playback of it
  starts. A Playback that goes on, such as on a TV, doesn't count. It stands for the whole Content,
  so a TV Show hides whichever TV Show Episode comes next, and their Watch Progress doesn't
  change. Each User sees only their own.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.History,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.Content

  postgres do
    table "hidden_from_home"
    repo WatchClub.Repo

    references do
      # The unique_content_per_user index starts with user_id
      reference :user, on_delete: :delete
      reference :content, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read]

    create :hide do
      description "Hide from Home: the actor hides the Content. Doing it again changes nothing."
      upsert? true
      upsert_identity :unique_content_per_user
      upsert_fields []

      accept [:content_id]

      change relate_actor(:user)
    end

    destroy :show do
      description "A new Playback of the Content started: the actor's Home may show it again, if they hid it."
      argument :content_id, :uuid_v7, allow_nil?: false

      # Only the actor's own: the read policy would forbid other Users' rows, not skip them
      change filter(expr(user_id == ^actor(:id) and content_id == ^arg(:content_id)))
    end
  end

  policies do
    policy actor_absent() do
      description "Hidden from Home actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:create) do
      authorize_if relating_to_actor(:user)
    end

    policy action_type([:read, :destroy]) do
      description "Each User sees, and shows again, only their own"
      authorize_if relates_to_actor_via(:user)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # Every Home of the User reloads its Content in progress
    publish_all :create, ["content", "user", :user_id]
    publish_all :destroy, ["content", "user", :user_id]
  end

  attributes do
    uuid_v7_primary_key :id
  end

  relationships do
    belongs_to :user, User do
      allow_nil? false
      attribute_writable? false
    end

    belongs_to :content, Content do
      allow_nil? false
    end
  end

  identities do
    identity :unique_content_per_user, [:user_id, :content_id]
  end
end
