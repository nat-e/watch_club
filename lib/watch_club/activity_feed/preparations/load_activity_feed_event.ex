defmodule WatchClub.ActivityFeed.Preparations.LoadActivityFeedEvent do
  @moduledoc """
  An Ash Preparation that loads all the data necessary to display the Activity Feed.
  """
  use Ash.Resource.Preparation

  @load [
    :scope_club,
    event: %{
      load: [
        club_created_event: [:actor, :club],
        content_added_event: [:actor, library_item: [:library, content: [:implementation]]],
        content_watched_event: [:actor, content: [:implementation]],
        library_created_event: [:actor, :library],
        member_added_event: [:actor, membership: :user]
      ]
    }
  ]
  def load_statement, do: @load

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> Ash.Query.load(@load)
  end
end
