defmodule WatchClub.ActivityFeed do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.ActivityFeed.Event

  alias WatchClub.ActivityFeed.Events.{
    ClubCreatedEvent,
    ContentAddedEvent,
    LibraryCreatedEvent,
    MemberAddedEvent
  }

  resources do
    resource Event do
      define :get_user_activity_feed, action: :for_actor
      define :get_club_activity_feed, action: :for_club, args: [:club_id]
    end

    resource ClubCreatedEvent
    resource ContentAddedEvent
    resource LibraryCreatedEvent
    resource MemberAddedEvent
  end
end
