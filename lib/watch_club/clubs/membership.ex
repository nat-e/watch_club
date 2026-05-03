defmodule WatchClub.Clubs.Membership do
  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Club, Invitation, MembershipRole}

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

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

    policy action([:read, :destroy]) do
      authorize_if {WatchClub.Clubs.Checks.ActorIsClubMemberFilter, role: :admin}
      authorize_if relates_to_actor_via(:user)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    prefix "memberships"
    publish_all :create, ["user", :user_id]
    publish :destroy, ["user", :user_id]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :role, MembershipRole, allow_nil?: false, public?: true

    timestamps()
  end

  relationships do
    belongs_to :club, Club, allow_nil?: false, public?: true
    belongs_to :user, User, allow_nil?: false, public?: true

    has_one :invitation, Invitation,
      allow_nil?: false,
      destination_attribute: :created_membership_id
  end

  identities do
    identity :club_and_user, [:club_id, :user_id]
  end
end
