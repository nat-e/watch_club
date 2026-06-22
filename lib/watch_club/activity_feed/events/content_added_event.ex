defmodule WatchClub.ActivityFeed.Events.ContentAddedEvent do
  @moduledoc """
  Payload of a :content_added Activity feed Event.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.ActivityFeed.Event
  alias WatchClub.Clubs.LibraryItem

  postgres do
    table "activity_feed_content_added_events"
    repo WatchClub.Repo

    references do
      reference :event, on_delete: :delete, on_update: :update
      reference :library_item, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, create: [:library_item_id]]
  end

  attributes do
    attribute :id, :uuid_v7 do
      primary_key? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :event, Event do
      primary_key? true
      allow_nil? false
      define_attribute? false
      source_attribute :id
    end

    belongs_to :library_item, LibraryItem, allow_nil?: false
  end

  identities do
    identity :unique_per_item, [:library_item_id]
  end
end
