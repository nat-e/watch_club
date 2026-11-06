defmodule WatchClubWeb.Storybook.ProgressBar do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.ProgressBar

  def function, do: &ProgressBar.progress_bar/1

  def variations do
    [
      %VariationGroup{
        id: :progress,
        description: "Not started, under way and finished",
        template: """
        <div class="flex w-64 flex-col gap-4">
          <.psb-variation-group />
        </div>
        """,
        variations: [
          %Variation{id: :empty, attributes: %{percent: 0}},
          %Variation{id: :under_way, attributes: %{percent: 35}},
          %Variation{id: :full, attributes: %{percent: 100}}
        ]
      }
    ]
  end
end
