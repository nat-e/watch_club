defmodule WatchClub.ActivityFeed.Calculations.ScopeEvent do
  @moduledoc """
  Resolves the single populated event of a FeedEventScope (its polymorphic payload).

  By default this calculation loads the event record.
  It is possible to add extra loading relations or calculations by passing a `load` argument,
  which will be merged with the defaults, e.g.
  `implementation: %{load: [content_watched_event: [:content, :completed]]}`.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, context) do
    [
      club_created_event: merge_load(context, :club_created_event),
      content_added_event: merge_load(context, :content_added_event),
      content_watched_event: merge_load(context, :content_watched_event),
      library_created_event: merge_load(context, :library_created_event),
      member_added_event: merge_load(context, :member_added_event)
    ]
  end

  defp merge_load(context, name, default \\ []) do
    custom_load = context.arguments[:load] || []
    # List.wrap so a single load term works like a list.
    default ++ List.wrap(Keyword.get(custom_load, name, []))
  end

  # Ensures all attributes are selected by default on the related loads we depend on.
  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(scopes, _, _) do
    Enum.map(
      scopes,
      &(&1.club_created_event || &1.library_created_event || &1.content_added_event ||
          &1.member_added_event || &1.content_watched_event)
    )
  end
end
