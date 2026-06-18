defmodule WatchClub.Clubs.Club do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    fragments: [WatchClub.PubSubDefaults]

  use Gettext, backend: WatchClubWeb.Gettext

  require Ash.Resource.Change.Builtins
  require Ash.Query

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.Changes.CreateAdminMembershipForActor
  alias WatchClub.Clubs.{Library, Membership}

  postgres do
    table "clubs"
    repo WatchClub.Repo
  end

  actions do
    defaults [:read, update: [:name]]

    read :preview

    update :reorder_libraries do
      description "Reorders the libraries that belong to a club"
      transaction? true
      touches_resources [Library]
      require_atomic? false

      argument :library_ids, {:array, :uuid_v7}, allow_nil?: true

      change WatchClub.Clubs.Changes.ReorderLibraries
    end

    create :create do
      accept [:name]

      change CreateAdminMembershipForActor
    end

    update :add_members do
      argument :user_ids, {:array, :uuid_v7} do
        allow_nil? false
        # Default is needed so that the form default value is [] and not nil
        default []
      end

      require_atomic? false

      change manage_relationship(:user_ids, :memberships,
               type: :create,
               on_no_match: {:create, :add_to_club},
               # Otherwise Ash sets the user_ids as :id key
               value_is_key: :user_id
             )
    end

    destroy :destroy do
      # Manually delete the memberships before deleting the club and send the PubSub notifications
      # This is done in the before_action hook so that we can keep the DB on_delete cascade
      # (even though not used here)
      change cascade_destroy(:memberships, return_notifications?: true, after_action?: false)
    end
  end

  policies do
    # Only the administrator can create clubs
    policy action(:create) do
      authorize_if actor_attribute_equals(:administrator?, true)
    end

    # Users can read only the clubs they are a member of; the instance
    # administrator can read all clubs (admin pages, invitation club grants)
    policy action(:read) do
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if expr(exists(memberships, user_id == ^actor(:id)))
    end

    # Only club admins can update and destroy it
    policy action([:update, :destroy, :add_members, :reorder_libraries]) do
      authorize_if expr(exists(memberships, user_id == ^actor(:id) and role == :admin))
    end
  end

  pub_sub do
    prefix "clubs"
    publish :update, [:id]
    publish :destroy, [:id]
    publish :reorder_libraries, [:id, "libraries"]
  end

  validations do
    # Customer-facing validations own localized messages for form errors.
    # Keep shape rules here instead of duplicating them as attribute constraints.
    validate present(:name) do
      message dgettext_noop("errors", "Club name is required")
    end

    validate string_length(:name, min: 3) do
      message dgettext_noop("errors", "Club name must be at least %{min} characters")
    end

    validate string_length(:name, max: 30) do
      message dgettext_noop("errors", "Club name cannot be longer than %{max} characters")
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :memberships, Membership do
      read_action :with_user
    end

    has_many :libraries, Library

    many_to_many :members, User, through: Membership
  end
end
