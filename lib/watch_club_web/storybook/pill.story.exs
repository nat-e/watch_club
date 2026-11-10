defmodule WatchClubWeb.Storybook.Pill do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Pill

  def function, do: &Pill.pill/1

  def variations do
    [
      %VariationGroup{
        id: :row,
        description: "A row of them, the second one current",
        template: """
        <div class="flex gap-related p-4 text-text">
          <.psb-variation-group />
        </div>
        """,
        variations: [
          %Variation{id: :season_1, attributes: %{current: false}, slots: ["Season 1"]},
          %Variation{id: :season_2, attributes: %{current: true}, slots: ["Season 2"]},
          %Variation{id: :season_3, attributes: %{current: false}, slots: ["Season 3"]}
        ]
      }
    ]
  end
end
