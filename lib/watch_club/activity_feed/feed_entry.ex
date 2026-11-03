defmodule WatchClub.ActivityFeed.FeedEntry do
  @moduledoc """
  A Feed Entry: the Feed Events of one User doing the same thing, within 12 hours of the entry's
  first event. `WatchClub.ActivityFeed.Changes.SetGroupKey` decides which entry an event joins.

  It reads the `activity_feed_entries` view, which has one row per `group_key` with the time of its
  latest event. A User can read an entry when they can read one of its scopes, and only loads the
  scopes they can read, one per event, so two Users can see the same entry with different events.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.ActivityFeed,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  alias WatchClub.ActivityFeed.FeedEventScope
  alias WatchClub.ActivityFeed.Preparations.LoadActivityFeedEvent

  postgres do
    # A view, created by the add_feed_entries migration
    table "activity_feed_entries"
    repo WatchClub.Repo
    migrate? false
  end

  actions do
    defaults [:read]

    read :for_actor do
      description "Get the Feed Entries visible to the current user, latest first"
      pagination keyset?: true, required?: false

      prepare build(
                sort: [latest_at: :desc, group_key: :asc],
                load: [scopes: LoadActivityFeedEvent.load_statement()]
              )
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if can_read(:scopes)
    end
  end

  attributes do
    attribute :group_key, :string, primary_key?: true, allow_nil?: false, public?: true

    # The time of the entry's latest event, among every scope, visible or not
    attribute :latest_at, :utc_datetime_usec, allow_nil?: false, public?: true
  end

  relationships do
    has_many :scopes, FeedEventScope do
      source_attribute :group_key
      destination_attribute :group_key
      read_action :distinct_per_event
    end
  end
end
