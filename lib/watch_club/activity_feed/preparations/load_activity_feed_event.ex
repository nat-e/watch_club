defmodule WatchClub.ActivityFeed.Preparations.LoadActivityFeedEvent do
  @moduledoc """
  An Ash Preparation that loads all the Event relationships necessary to display the Activity Feed
  """
  use Ash.Resource.Preparation

  @load [
    :actor,
    :scope_club,
    club_created: [:club],
    library_created: [:library],
    content_added: [library_item: [:library, content: :implementation]],
    member_added: [membership: :user]
  ]
  def load_statement, do: @load

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> Ash.Query.load(@load)
  end
end
