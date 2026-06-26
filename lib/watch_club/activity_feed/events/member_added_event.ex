defmodule WatchClub.ActivityFeed.Events.MemberAddedEvent do
  @moduledoc """
  A :member_added activity feed event: a User joined a Club.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Accounts.User
  alias WatchClub.ActivityFeed.FeedEventScope
  alias WatchClub.Clubs.Membership

  postgres do
    table "activity_feed_member_added_events"
    repo WatchClub.Repo

    references do
      reference :membership, on_delete: :delete, on_update: :update
      reference :actor, on_delete: :nilify, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:membership_id]
      argument :scopes, {:array, :map}, allow_nil?: false

      # Actor is nullable here, since when they join via registering actor is not set
      change relate_actor(:actor, allow_nil?: true)
      change manage_relationship(:scopes, type: :create)
    end
  end

  attributes do
    uuid_v7_primary_key :id
  end

  relationships do
    belongs_to :membership, Membership, allow_nil?: false
    belongs_to :actor, User, allow_nil?: true
    has_many :scopes, FeedEventScope, destination_attribute: :member_added_event_id
  end

  identities do
    identity :unique_per_membership, [:membership_id]
  end
end
