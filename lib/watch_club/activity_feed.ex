defmodule WatchClub.ActivityFeed do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.ActivityFeed.FeedEventScope

  alias WatchClub.ActivityFeed.Events.{
    ClubCreatedEvent,
    ContentAddedEvent,
    ContentWatchedEvent,
    LibraryCreatedEvent,
    MemberAddedEvent
  }

  resources do
    resource FeedEventScope do
      define :get_user_activity_feed, action: :for_actor
      define :get_club_activity_feed, action: :for_club, args: [:club_id]
      define :get_content_activity_feed, action: :for_content, args: [:content_identity]
    end

    resource ClubCreatedEvent
    resource ContentAddedEvent
    resource ContentWatchedEvent
    resource LibraryCreatedEvent
    resource MemberAddedEvent
  end
end
