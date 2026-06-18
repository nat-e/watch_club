defmodule WatchClub.Clubs.Membership do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    fragments: [WatchClub.PubSubDefaults]

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Club, MembershipRole}

  postgres do
    table "memberships"
    repo WatchClub.Repo

    references do
      reference :club, on_delete: :delete, on_update: :update
      reference :user, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy, create: [:*], update: []]

    read :with_user do
      prepare build(load: [:user])
    end

    read :with_club_and_user do
      prepare build(
                load: [:club, :user],
                context: %{private: %{authorize?: false}}
              )
    end

    create :add_to_club do
      description "Instance administrator adds an existing user to a club as a club member"
      accept [:club_id, :user_id]

      change set_attribute(:role, :member)
    end

    destroy :leave_club
  end

  policies do
    # Membership creation is always forbidden and is always done via
    # Club:create and invitation redemption where authorization is skipped
    policy action(:create) do
      forbid_if always()
    end

    policy action(:add_to_club) do
      authorize_if {WatchClub.Clubs.Checks.ActorIsClubMember, role: :admin}
    end

    policy action([:read, :with_user, :with_club_and_user]) do
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if {WatchClub.Clubs.Checks.ActorIsClubMemberFilter, role: :admin}
      authorize_if relates_to_actor_via(:user)
    end

    policy action(:destroy) do
      forbid_if expr(role == :admin)
      authorize_if {WatchClub.Clubs.Checks.ActorIsClubMemberFilter, role: :admin}
    end

    policy action(:leave_club) do
      forbid_if expr(role == :admin)
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  pub_sub do
    publish :create, ["users", :user_id, "memberships"]
    publish :create, ["clubs", :club_id, "memberships"]
    publish :add_to_club, ["users", :user_id, "memberships"]
    publish :add_to_club, ["clubs", :club_id, "memberships"]
    publish :leave_club, ["users", :user_id, "memberships"]
    publish :leave_club, ["clubs", :club_id, "memberships"]
    publish :destroy, ["users", :user_id, "memberships"]
    publish :destroy, ["clubs", :club_id, "memberships"]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :role, MembershipRole, allow_nil?: false, public?: true

    timestamps public?: true
  end

  relationships do
    belongs_to :club, Club, allow_nil?: false, public?: true
    belongs_to :user, User, allow_nil?: false, public?: true
  end

  identities do
    identity :club_and_user, [:club_id, :user_id]
  end
end
