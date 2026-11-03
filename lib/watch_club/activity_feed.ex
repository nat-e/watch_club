defmodule WatchClub.ActivityFeed do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.ActivityFeed.{FeedEntry, FeedEventScope}

  alias WatchClub.ActivityFeed.Events.{
    ClubCreatedEvent,
    ContentAddedEvent,
    ContentWatchedEvent,
    LibraryCreatedEvent,
    MemberAddedEvent
  }

  resources do
    resource FeedEntry do
      define :get_user_activity_feed, action: :for_actor

      define :get_user_feed_entry,
        action: :for_actor,
        get_by: [:group_key],
        not_found_error?: false
    end

    resource FeedEventScope do
      define :get_content_activity_feed, action: :for_content, args: [:content_identity]
    end

    resource ClubCreatedEvent
    resource ContentAddedEvent
    resource ContentWatchedEvent
    resource LibraryCreatedEvent
    resource MemberAddedEvent
  end
end
