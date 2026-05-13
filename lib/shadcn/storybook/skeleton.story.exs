defmodule Shadcn.Storybook.Skeleton do
  use PhoenixStorybook.Story, :component

  def function, do: &Shadcn.Components.Skeleton.skeleton/1

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
        id: :panel,
        description: "Panel",
        template: """
        <div class="flex w-full max-w-xs flex-col gap-4 rounded-xl bg-card p-4 shadow-xs ring-1 ring-foreground/10">
          <div class="grid gap-2">
            <.skeleton class="h-4 w-2/3" />
            <.skeleton class="h-4 w-1/2" />
          </div>
          <.skeleton class="aspect-video w-full" />
        </div>
        """
      }
    ]
  end
end
