defmodule WatchClub.ActivityFeed.Calculations.ScopeEvent do
  @moduledoc """
  Resolves the single populated event of a FeedEventScope (its polymorphic payload).

  The calculation can be loaded with a `load` argument to allow loading relationships
  and calculations on the different events.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, context) do
    case context.arguments[:load] do
      nil ->
        [
          :club_created_event,
          :content_added_event,
          :content_watched_event,
          :library_created_event,
          :member_added_event
        ]

      load ->
        load
    end
  end

  # Ensures all attributes are selected by default on the related loads we depend on.
  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(scopes, _, _) do
    Enum.map(scopes, fn scope ->
      scope.club_created_event || scope.library_created_event || scope.content_added_event ||
        scope.member_added_event || scope.content_watched_event
    end)
  end
end
