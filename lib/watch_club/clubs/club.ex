defmodule WatchClub.Clubs.Club do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  require Ash.Resource.Change.Builtins
  require Ash.Query

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.Changes.CreateAdminMembershipForActor
  alias WatchClub.Clubs.{Invitation, Library, Membership}

  postgres do
    table "clubs"
    repo(WatchClub.Repo)
  end

  actions do
    defaults [:read, update: [:name]]

    read :preview

    read :members_and_invitations do
      prepare build(load: [:invitations, :memberships])
    end

    action :reorder_libraries, {:array, :struct} do
      description "Reorders the libraries that belong to a club"
      constraints items: [instance_of: Library]
      transaction? true
      touches_resources [Library]

      argument :club_id, :uuid_v7, allow_nil?: false
      argument :library_ids, {:array, :uuid_v7}, allow_nil?: true

      run WatchClub.Clubs.Actions.ReorderLibraries
    end

    create :create do
      accept [:name]

      change CreateAdminMembershipForActor
    end

    destroy :destroy do
      # Manually delete the memberships before deleting the club and send the PubSub notifications
      # This is done in the before_action hook so that we can keep the DB on_delete cascade
      # (even though not used here)
      change cascade_destroy(:memberships, return_notifications?: true, after_action?: false)
    end
  end

  policies do
    # All actions will be forbidden without an actor
    policy actor_absent() do
      access_type :strict
      forbid_if always()
    end

    # Only the administrator can create clubs
    policy action(:create) do
      authorize_if actor_attribute_equals(:administrator?, true)
    end

    # Users can read only the clubs they are a member of
    policy action(:read) do
      # We can't use the ActorIsClubMember here because we need a filter check
      authorize_if expr(exists(memberships, user_id == ^actor(:id)))
    end

    # Only club admins can update and destroy it
    policy action([:update, :destroy, :members_and_invitations]) do
      authorize_if expr(exists(memberships, user_id == ^actor(:id) and role == :admin))
    end

    policy action(:reorder_libraries) do
      authorize_if {WatchClub.Clubs.Checks.ActorIsClubMember, role: :admin}
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    prefix "clubs"
    publish :update, [:id]
  end

  validations do
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
      constraints min_length: 3, max_length: 30
    end

    timestamps()
  end

  relationships do
    has_many :memberships, Membership do
      read_action :with_user_and_invitation
    end

    has_many :invitations, Invitation do
      read_action :list_club_invitations
    end

    has_many :libraries, Library

    many_to_many :members, User, through: Membership
  end
end
