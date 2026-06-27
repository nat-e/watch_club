defmodule WatchClub.Clubs.Membership do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Clubs,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Club, MembershipRole}

  postgres do
    table "memberships"
    repo WatchClub.Repo

    references do
      reference :club, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy, update: []]

    read :with_user do
      prepare build(load: [:user])
    end

    read :with_club_and_user do
      prepare build(
                load: [:club, :user],
                context: %{private: %{authorize?: false}}
              )
    end

    create :create do
      primary? true
      accept [:club_id, :user_id, :role]

      change WatchClub.ActivityFeed.Changes.CreateActivityFeedEvent
    end

    create :add_to_club do
      description "Instance administrator adds an existing user to a club as a club member"
      accept [:club_id, :user_id]

      change set_attribute(:role, :member)

      change WatchClub.ActivityFeed.Changes.CreateActivityFeedEvent
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

    policy action_type(:read) do
      authorize_if WatchClub.Clubs.Checks.ActorIsClubMemberFilter
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

    publish_all :create, ["user", :user_id]
    publish_all :create, ["memberships", "club", :club_id]
    publish_all :destroy, ["user", :user_id]
    publish_all :destroy, ["memberships", "club", :club_id]
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
