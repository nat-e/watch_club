defmodule Shadcn.Storybook.ScrollArea do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.ScrollArea

  def function, do: &ScrollArea.scroll_area/1

  def variations do
    [
      %Variation{
        id: :tags,
        description: "Vertical scroll",
        template: """
        <.scroll_area class="h-72 w-56 rounded-md border">
          <div class="p-4 text-sm">
            <h4 class="mb-4 font-medium">Tags</h4>
            #{for i <- 1..30 do
          ~s|<div class="border-b py-2">v1.2.0-tag-#{i}</div>|
        end |> Enum.join("\n")}
          </div>
        </.scroll_area>
        """
      },
      %Variation{
        id: :horizontal,
        description: "Horizontal scroll (whitespace-nowrap)",
        template: """
        <.scroll_area class="w-96 rounded-md border whitespace-nowrap">
          <div class="flex gap-4 p-4">
            #{for i <- 1..15 do
          ~s|<div class="size-32 shrink-0 rounded-md bg-muted text-center text-sm leading-32">Photo #{i}</div>|
        end |> Enum.join("\n")}
          </div>
        </.scroll_area>
        """
      }
    ]
  end
end
