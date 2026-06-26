defmodule WatchClub.ActivityFeed.Preparations.DistinctPerEvent do
  @moduledoc """
  Dedupes feed scopes to one row per underlying event.

  An event fans out to several scopes (a user's personal scope + one per club whose library holds the
  content). When a member views their feed, more than one of those scopes can be visible for the same
  event. We DISTINCT ON the five event FK columns (exactly one is set per row, so the tuple uniquely
  identifies the event).
  """
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> Ash.Query.distinct([
      :club_created_event_id,
      :library_created_event_id,
      :content_added_event_id,
      :member_added_event_id,
      :content_watched_event_id
    ])
  end
end
