defmodule WatchClub.ActivityFeed.EventType do
  @moduledoc """
  An Enum that defines all the different types of feed Activities
  """

  use Ash.Type.Enum,
    values: [
      :club_created,
      :library_created,
      :content_added,
      :member_added
    ]
end
