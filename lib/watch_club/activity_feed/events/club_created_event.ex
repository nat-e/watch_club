defmodule WatchClub.ActivityFeed.Events.ClubCreatedEvent do
  @moduledoc """
  Payload of a :club_created Activity feed Event.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.ActivityFeed.Event
  alias WatchClub.Clubs.Club

  postgres do
    table "activity_feed_club_created_events"
    repo WatchClub.Repo

    references do
      reference :event, on_delete: :delete, on_update: :update
      reference :club, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, create: [:club_id]]
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

    belongs_to :club, Club, allow_nil?: false
  end

  identities do
    identity :unique_per_club, [:club_id]
  end
end
