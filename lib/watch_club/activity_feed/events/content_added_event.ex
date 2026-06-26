defmodule WatchClub.ActivityFeed.Events.ContentAddedEvent do
  @moduledoc """
  A :content_added activity feed event: a User added a Content to a Club's library.

  Content is reached through `library_item` for display, and through the denormalized
  `FeedEventScope.content` for the content-detail feed.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.Accounts.User
  alias WatchClub.ActivityFeed.FeedEventScope
  alias WatchClub.Clubs.LibraryItem

  postgres do
    table "activity_feed_content_added_events"
    repo WatchClub.Repo

    references do
      reference :library_item, on_delete: :delete, on_update: :update
      reference :actor, on_delete: :nilify, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:library_item_id]
      argument :scopes, {:array, :map}, allow_nil?: false

      change relate_actor(:actor)
      change manage_relationship(:scopes, type: :create)
    end
  end

  attributes do
    uuid_v7_primary_key :id
  end

  relationships do
    belongs_to :library_item, LibraryItem, allow_nil?: false
    belongs_to :actor, User, allow_nil?: true
    has_many :scopes, FeedEventScope
  end

  identities do
    identity :unique_per_item, [:library_item_id]
  end
end
