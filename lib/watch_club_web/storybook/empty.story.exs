defmodule WatchClubWeb.Storybook.Empty do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Empty

  def function, do: &Empty.empty/1

  def imports do
    [
      {WatchClubWeb.Components.UI.Button, [button: 1]},
      {Lucideicons, [bell: 1, library: 1, plus: 1, refresh_ccw: 1, search: 1]}
    ]
  end

  defp container_template(content) do
    """
    <div class="w-full max-w-2xl p-4 text-text">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default empty state with one primary action",
        slots: [
          ~s|<:icon><Lucideicons.library /></:icon>|,
          ~s|<:title>No libraries yet</:title>|,
          ~s|<:description>Create libraries to add movies, TV shows, or books to your club.</:description>|,
          ~s|<.button id="empty-story-create-library-button"><Lucideicons.plus />Create library</.button>|
        ]
      },
      %Variation{
        id: :search,
        description: "Search or filter zero-state",
        slots: [
          ~s|<:icon><Lucideicons.search /></:icon>|,
          ~s|<:title>No results found</:title>|,
          ~s|<:description>Try adjusting your search terms or clearing active filters.</:description>|,
          ~s|<.button id="empty-story-clear-filters-button" variant="secondary"><Lucideicons.refresh_ccw />Clear filters</.button>|
        ]
      },
      %Variation{
        id: :compact,
        description: "Compact empty state for constrained surfaces",
        attributes: %{size: "sm"},
        slots: [
          ~s|<:icon><Lucideicons.search /></:icon>|,
          ~s|<:title>No results found</:title>|,
          ~s|<:description>Try adjusting your search terms.</:description>|
        ]
      },
      %Variation{
        id: :quiet,
        description: "Lower-emphasis empty state",
        attributes: %{border: false},
        slots: [
          ~s|<:icon class="bg-surface-inset"><Lucideicons.bell /></:icon>|,
          ~s|<:title>No notifications</:title>|,
          ~s|<:description>You're all caught up. New club updates will appear here.</:description>|
        ]
      },
      %Variation{
        id: :compact_quiet,
        description: "Compact borderless empty state for popovers",
        attributes: %{border: false, size: "sm"},
        slots: [
          ~s|<:icon><Lucideicons.search /></:icon>|,
          ~s|<:title class="font-normal text-text-muted">Start typing to search</:title>|
        ]
      },
      %Variation{
        id: :no_icon,
        description: "Empty state without an icon",
        slots: [
          ~s|<:title>Nothing here yet</:title>|,
          ~s|<:description>Once activity starts, the latest club updates will appear here.</:description>|,
          ~s|<.button id="empty-story-refresh-button" variant="secondary">Refresh</.button>|
        ]
      }
    ]
  end
end
