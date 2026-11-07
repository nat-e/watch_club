defmodule WatchClub.ActivityFeed.Changes.SetGroupKey do
  @moduledoc """
  Puts a Feed Event in a Feed Entry by setting its `group_key` from its actor.

  A group says who did what, such as `watched:<user id>`. The key adds the time the entry started,
  in Unix seconds: an event joins the entry of the latest event with the same group when that entry
  started less than 12 hours ago, and starts a new entry otherwise.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.ActivityFeed.Events.ContentWatchedEvent

  @entry_span_seconds 12 * 60 * 60

  @impl true
  def change(changeset, _opts, _context) do
    actor_id = Ash.Changeset.get_attribute(changeset, :actor_id)

    Ash.Changeset.before_action(changeset, fn changeset ->
      now = DateTime.to_unix(DateTime.utc_now())

      started_at =
        case latest_entry_start!(actor_id) do
          started_at when is_integer(started_at) and now - started_at < @entry_span_seconds ->
            started_at

          _no_open_entry ->
            now
        end

      Ash.Changeset.force_change_attribute(
        changeset,
        :group_key,
        "watched:#{actor_id}:#{started_at}"
      )
    end)
  end

  defp latest_entry_start!(actor_id) do
    ContentWatchedEvent
    |> Ash.Query.filter(actor_id == ^actor_id)
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.Query.select([:group_key])
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> nil
      event -> event.group_key |> String.split(":") |> List.last() |> String.to_integer()
    end
  end
end
