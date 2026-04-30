defmodule Shadcn.Storybook.AspectRatio do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.AspectRatio

  def function, do: &AspectRatio.aspect_ratio/1

  defp container_template(content) do
    """
    <div class="w-[260px]">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :landscape_16_9,
        description: "16/9 landscape",
        attributes: %{ratio: 16 / 9, class: "bg-muted rounded-md overflow-hidden"},
        slots: [
          ~s|<div class="flex size-full items-center justify-center text-muted-foreground">16:9</div>|
        ]
      },
      %Variation{
        id: :portrait_3_4,
        description: "3/4 portrait",
        attributes: %{ratio: 3 / 4, class: "bg-muted rounded-md overflow-hidden"},
        slots: [
          ~s|<div class="flex size-full items-center justify-center text-muted-foreground">3:4</div>|
        ]
      },
      %Variation{
        id: :square,
        description: "1/1 square",
        attributes: %{ratio: 1.0, class: "bg-muted rounded-md overflow-hidden"},
        slots: [
          ~s|<div class="flex size-full items-center justify-center text-muted-foreground">1:1</div>|
        ]
      }
    ]
  end
end
