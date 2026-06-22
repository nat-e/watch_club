defmodule WatchClub.ActivityFeed.Events.MemberAddedEvent do
  @moduledoc """
  Payload of a :member_added Activity feed Event.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.ActivityFeed.Event
  alias WatchClub.Clubs.Membership

  postgres do
    table "activity_feed_member_added_events"
    repo WatchClub.Repo

    references do
      reference :event, on_delete: :delete, on_update: :update
      reference :membership, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, create: [:membership_id]]
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

    belongs_to :membership, Membership, allow_nil?: false
  end

  identities do
    identity :unique_per_membership, [:membership_id]
  end
end
