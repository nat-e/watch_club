defmodule WatchClub.ActivityFeed.Events.ClubCreatedEvent do
  @moduledoc """
  A :club_created activity feed event: a User created a Club.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Accounts.User
  alias WatchClub.ActivityFeed.FeedEventScope
  alias WatchClub.Clubs.Club

  postgres do
    table "activity_feed_club_created_events"
    repo WatchClub.Repo

    references do
      reference :club, on_delete: :delete
      reference :actor, on_delete: :nilify
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:club_id]
      argument :scopes, {:array, :map}, allow_nil?: false

      change relate_actor(:actor)
      change manage_relationship(:scopes, type: :create)
    end
  end

  attributes do
    uuid_v7_primary_key :id
  end

  relationships do
    belongs_to :club, Club, allow_nil?: false
    belongs_to :actor, User, allow_nil?: true
    has_many :scopes, FeedEventScope
  end

  identities do
    identity :unique_per_club, [:club_id]
  end
end
