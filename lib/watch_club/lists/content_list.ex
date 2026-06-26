defmodule WatchClub.Lists.ContentList do
  @moduledoc """
  A private, user-owned collection of `Content`.
  User can create and manage as many Lists as they want.
  They automatically get a `To Watch` list when their account is created.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Lists,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.Content
  alias WatchClub.Lists.ListItem
  alias WatchClub.Shared.LucideIcon

  postgres do
    table "lists"
    repo WatchClub.Repo

    references do
      reference :owner, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, update: [:name, :icon]]

    create :create do
      primary? true
      accept [:name, :icon]

      change relate_actor(:owner)
    end
  end

  policies do
    policy action_type(:create) do
      description "Users can only create lists for themselves"
      authorize_if relating_to_actor(:owner)
    end

    policy action_type([:read, :update, :destroy]) do
      description "Users can only access their own lists"
      authorize_if relates_to_actor_via(:owner)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish_all :create, ["user", :owner_id]
    publish_all :update, ["user", :owner_id]
    publish_all :destroy, ["user", :owner_id]
  end

  validations do
    # Customer-facing validations own localized messages for form errors.
    # Keep shape rules here instead of duplicating them as attribute constraints.
    validate present(:name) do
      message dgettext_noop("errors", "List name is required")
    end

    validate string_length(:name, min: 3) do
      message dgettext_noop("errors", "List name must be at least %{min} characters")
    end

    validate string_length(:name, max: 30) do
      message dgettext_noop("errors", "List name cannot be longer than %{max} characters")
    end

    validate one_of(:icon, LucideIcon.names()) do
      message dgettext_noop("errors", "List icon is invalid")
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :icon, :string do
      public? true
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :owner, User do
      allow_nil? false
      attribute_writable? false
    end

    has_many :items, ListItem do
      destination_attribute :list_id
      sort created_at: :desc
    end

    many_to_many :contents, Content do
      through ListItem
      source_attribute_on_join_resource :list_id
      destination_attribute_on_join_resource :content_id
    end
  end
end
