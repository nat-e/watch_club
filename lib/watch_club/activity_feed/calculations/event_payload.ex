defmodule WatchClub.ActivityFeed.Calculations.EventPayload do
  use Ash.Resource.Calculation

  @impl true
  def load(_, _, _) do
    [:club_created, :library_created, :content_added, :member_added]
  end

  # This ensures that all attributes are selected by default
  # on the related loads we depend on.
  @impl true
  def strict_loads?, do: false

  @impl true
  def calculate(events, _, _) do
    Enum.map(events, fn event ->
      cond do
        event.club_created ->
          event.club_created

        event.library_created ->
          event.library_created

        event.content_added ->
          event.content_added

        event.member_added ->
          event.member_added
      end
    end)
  end
end
