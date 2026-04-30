defmodule Shadcn.Storybook.Separator do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Separator

  def function, do: &Separator.separator/1

  def variations do
    [
      %Variation{
        id: :horizontal,
        description: "Horizontal (default)",
        template: """
        <div class="w-64">
          <p class="text-sm">Above</p>
          <.psb-variation/>
          <p class="text-sm">Below</p>
        </div>
        """
      },
      %Variation{
        id: :vertical,
        description: "Vertical",
        attributes: %{orientation: "vertical"},
        template: """
        <div class="flex h-8 items-center gap-3">
          <span class="text-sm">Left</span>
          <.psb-variation/>
          <span class="text-sm">Right</span>
        </div>
        """
      },
      %Variation{
        id: :semantic,
        description: "Semantic (decorative=false) — exposed as role=\"separator\"",
        attributes: %{decorative: false},
        template: """
        <div class="w-64">
          <p class="text-sm">Section A</p>
          <.psb-variation/>
          <p class="text-sm">Section B</p>
        </div>
        """
      }
    ]
  end
end
