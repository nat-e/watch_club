defmodule WatchClub.ActivityFeed.FeedEntry do
  @moduledoc """
  The watching Feed Events of one User within 12 hours of the entry's first event.
  Every User sees every entry, latest activity first.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    data_layer: AshPostgres.DataLayer

  alias WatchClub.ActivityFeed.Events.ContentWatchedEvent

  postgres do
    table "activity_feed_entries"
    repo WatchClub.Repo
    migrate? false
  end

  actions do
    defaults [:read]

    read :for_actor do
      pagination keyset?: true, required?: false

      prepare build(
                sort: [latest_at: :desc, group_key: :asc],
                load: [events: [:actor, content: [:implementation]]]
              )
    end
  end

  attributes do
    attribute :group_key, :string, primary_key?: true, allow_nil?: false, public?: true
    attribute :latest_at, :utc_datetime_usec, allow_nil?: false, public?: true
  end

  relationships do
    has_many :events, ContentWatchedEvent do
      source_attribute :group_key
      destination_attribute :group_key
      sort created_at: :desc, id: :desc
    end
  end
end
