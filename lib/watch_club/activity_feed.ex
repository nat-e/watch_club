defmodule WatchClub.ActivityFeed do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.ActivityFeed.Events.ContentWatchedEvent
  alias WatchClub.ActivityFeed.FeedEntry

  resources do
    resource FeedEntry do
      define :get_user_activity_feed, action: :for_actor

      define :get_user_feed_entry, action: :for_actor, get_by: [:group_key]
    end

    resource ContentWatchedEvent do
      define :add_content_watched_event, action: :add, args: [:content_id, :tv_show_episode_id]
    end
  end
end
