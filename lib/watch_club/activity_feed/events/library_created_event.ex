defmodule WatchClub.ActivityFeed.Events.LibraryCreatedEvent do
  @moduledoc """
  A :library_created activity feed event: a User created a Library in a Club.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Accounts.User
  alias WatchClub.ActivityFeed.FeedEventScope
  alias WatchClub.Clubs.Library

  postgres do
    table "activity_feed_library_created_events"
    repo WatchClub.Repo

    references do
      reference :library, on_delete: :delete
      reference :actor, on_delete: :nilify
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:library_id]
      argument :scopes, {:array, :map}, allow_nil?: false

      change relate_actor(:actor)
      change manage_relationship(:scopes, type: :create)
    end
  end

  attributes do
    uuid_v7_primary_key :id
  end

  relationships do
    belongs_to :library, Library, allow_nil?: false
    belongs_to :actor, User, allow_nil?: true
    has_many :scopes, FeedEventScope
  end

  identities do
    identity :unique_per_library, [:library_id]
  end
end
