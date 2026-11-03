defmodule WatchClub.ActivityFeed.Changes.SetGroupKey do
  @moduledoc """
  Puts a Feed Event in a Feed Entry by setting its scope's `group_key` from the `group` argument.

  A group says who did what, such as `watched:<user id>`. The key adds the time the entry started,
  in Unix seconds: an event joins the entry of the latest scope with the same group when that entry
  started less than 12 hours ago, and starts a new entry otherwise. An event that is never grouped,
  such as a club creation, gets a group of its own, such as `club:<club id>`.

  Groups contain no `_` or `%`, because the lookup matches them with `LIKE`.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.ActivityFeed.FeedEventScope

  @entry_span_seconds 12 * 60 * 60

  @impl true
  def change(changeset, _opts, _context) do
    group = Ash.Changeset.get_argument(changeset, :group)

    Ash.Changeset.before_action(changeset, fn changeset ->
      now = DateTime.to_unix(DateTime.utc_now())

      started_at =
        case latest_entry_start(group) do
          started_at when is_integer(started_at) and now - started_at < @entry_span_seconds ->
            started_at

          _no_open_entry ->
            now
        end

      Ash.Changeset.force_change_attribute(changeset, :group_key, "#{group}:#{started_at}")
    end)
  end

  defp latest_entry_start(group) do
    FeedEventScope
    |> Ash.Query.filter(like(group_key, ^"#{group}:%"))
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.Query.select([:group_key])
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> nil
      scope -> scope.group_key |> String.split(":") |> List.last() |> String.to_integer()
    end
  end
end
