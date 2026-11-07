defmodule WatchClub.ActivityFeed do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.ActivityFeed.Events.ContentWatchedEvent
  alias WatchClub.ActivityFeed.FeedEntry

  resources do
    resource FeedEntry do
      define :get_user_activity_feed, action: :for_actor

      define :get_user_feed_entry,
        action: :for_actor,
        get_by: [:group_key],
        not_found_error?: false
    end

    resource ContentWatchedEvent
  end
end
