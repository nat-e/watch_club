defmodule WatchClub.Clubs.Club do
  require Ash.Resource.Change.Builtins
  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Invitation, Membership}

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "clubs"
    repo(WatchClub.Repo)
  end

  actions do
    defaults [:read, :destroy, update: [:name]]

    read :preview

    create :create do
      accept [:name]

      # This is OK to do in an anonymous function because adding a row in another table
      # cannot be made atomic anyway
      change fn
        changeset, %{actor: %User{} = actor} ->
          Ash.Changeset.manage_relationship(
            changeset,
            :memberships,
            [%{user_id: actor.id, role: :admin}],
            type: :create,
            authorize?: false
          )

        # The changeset is still being executed when the actor is nil, even if policy forbids it
        changeset, _ ->
          changeset
      end
    end
  end

  policies do
    # All actions will be forbidden without an actor
    policy actor_absent() do
      access_type :strict
      forbid_if always()
    end

    # Everyone can create a club
    policy action(:create) do
      authorize_if always()
    end

    # Users can read only the clubs they are a member of
    policy action(:read) do
      # We can't use the ActorIsClubMember here because we need a filter check
      authorize_if expr(exists(memberships, user_id == ^actor(:id)))
    end

    # Only club admins can update and destroy it
    policy action([:update, :destroy]) do
      authorize_if expr(exists(memberships, user_id == ^actor(:id) and role == :admin))
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 2, max_length: 30
    end

    timestamps()
  end

  relationships do
    has_many :memberships, Membership
    has_many :invitations, Invitation
    many_to_many :members, User, through: Membership
  end
end
