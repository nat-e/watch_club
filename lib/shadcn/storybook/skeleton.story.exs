defmodule Shadcn.Storybook.Skeleton do
  use PhoenixStorybook.Story, :component

  def function, do: &Shadcn.Components.Skeleton.skeleton/1
  def imports, do: [{Shadcn.Components.Card, [card: 1]}]

  def variations do
    [
      %Variation{
        id: :text,
        description: "Text",
        template: """
        <div class="flex w-full max-w-xs flex-col gap-2">
          <.skeleton class="h-4 w-full" />
          <.skeleton class="h-4 w-full" />
          <.skeleton class="h-4 w-3/4" />
        </div>
        """
      },
      %Variation{
        id: :avatar,
        description: "Avatar",
        template: """
        <div class="flex w-fit items-center gap-4">
          <.skeleton class="size-10 shrink-0 rounded-full" />
          <div class="grid gap-2">
            <.skeleton class="h-4 w-[150px]" />
            <.skeleton class="h-4 w-[100px]" />
          </div>
        </div>
        """
      },
      %Variation{
        id: :card,
        description: "Card",
        template: """
        <.card class="w-full max-w-xs">
          <:title><.skeleton class="h-4 w-2/3" /></:title>
          <:description><.skeleton class="h-4 w-1/2" /></:description>
          <.skeleton class="aspect-video w-full" />
        </.card>
        """
      }
    ]
  end
end
