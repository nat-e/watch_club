defmodule WatchClub.Clubs.Membership do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Club, Invitation, MembershipRole}

  postgres do
    table "memberships"
    repo(WatchClub.Repo)

    references do
      reference(:club, on_delete: :delete, on_update: :update)
      reference(:user, on_delete: :delete, on_update: :update)
    end
  end

  actions do
    defaults [:read, :destroy, create: [:*]]

    read :with_user do
      prepare build(load: [:user])
    end

    read :with_club_and_user do
      prepare build(
                load: [:club, :user],
                context: %{private: %{authorize?: false}}
              )
    end

    destroy :leave_club
  end

  policies do
    policy actor_absent() do
      forbid_if always()
    end

    # Membership creation is always forbidden and is always done via
    # Club:create and Invitation:accept where authorization is skipped
    policy action(:create) do
      forbid_if always()
    end

    policy action([:read, :with_user, :with_club_and_user]) do
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
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish :create, ["users", :user_id, "memberships"]
    publish :create, ["clubs", :club_id, "memberships"]
    publish :leave_club, ["users", :user_id, "memberships"]
    publish :leave_club, ["clubs", :club_id, "memberships"]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :role, MembershipRole, allow_nil?: false, public?: true

    timestamps public?: true
  end

  relationships do
    belongs_to :club, Club, allow_nil?: false, public?: true
    belongs_to :user, User, allow_nil?: false, public?: true

    belongs_to :invitation, Invitation do
      allow_nil? true
    end
  end

  identities do
    identity :club_and_user, [:club_id, :user_id]
    identity :invitation_id, [:invitation_id]
  end
end
