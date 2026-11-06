defmodule WatchClubWeb.Storybook.FilterChip do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.FilterChip

  def function, do: &FilterChip.filter_chip/1
  def imports, do: [{Lucideicons, [library: 1]}]

  def variations do
    [
      %VariationGroup{
        id: :states,
        description: "Off and on",
        template: """
        <div class="flex flex-wrap items-center gap-2">
          <.psb-variation-group />
        </div>
        """,
        variations: [
          %Variation{
            id: :off,
            attributes: %{on: false},
            slots: ["<:icon><Lucideicons.library /></:icon>", "In the library"]
          },
          %Variation{
            id: :on,
            attributes: %{on: true},
            slots: ["<:icon><Lucideicons.library /></:icon>", "In the library"]
          }
        ]
      },
      %VariationGroup{
        id: :radio,
        description: "One of a group where only one is on",
        template: """
        <div role="radiogroup" aria-label="Type" class="flex flex-wrap items-center gap-2">
          <.psb-variation-group />
        </div>
        """,
        variations: [
          %Variation{id: :all, attributes: %{on: true, radio: true}, slots: ["All"]},
          %Variation{id: :movies, attributes: %{on: false, radio: true}, slots: ["Movies"]}
        ]
      },
      %Variation{
        id: :without_icon,
        description: "Without icon",
        attributes: %{on: false},
        slots: ["Movies"]
      }
    ]
  end
end
