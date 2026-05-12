defmodule Shadcn.Storybook.HoverCard do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.HoverCard

  def function, do: &HoverCard.hover_card/1
  def imports, do: [{WatchClubWeb.UI.Button, [button: 1]}]

  defp container_template(content) do
    """
    <div class="flex min-h-[320px] items-center justify-center p-12">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :demo,
        description: "@nextjs profile preview",
        attributes: %{id: "hc-demo", open_delay: 10, close_delay: 100},
        slots: [
          ~s|<:trigger><.button variant="link">Hover Here</.button></:trigger>|,
          """
          <div class="flex flex-col gap-0.5">
            <div class="font-semibold">@nextjs</div>
            <div>The React Framework – created and maintained by @vercel.</div>
            <div class="mt-1 text-xs text-muted-foreground">Joined December 2021</div>
          </div>
          """
        ]
      },
      %VariationGroup{
        id: :sides,
        description: "Hover cards anchored to each side of the trigger",
        template: """
        <div class="flex flex-wrap justify-center gap-2">
          <.psb-variation-group/>
        </div>
        """,
        variations:
          for side <- ~w(left top bottom right) do
            %Variation{
              id: :"side_#{side}",
              attributes: %{
                id: "hc-side-#{side}",
                side: side,
                open_delay: 100,
                close_delay: 100
              },
              slots: [
                ~s|<:trigger><.button variant="outline" class="capitalize">#{side}</.button></:trigger>|,
                """
                <div class="flex flex-col gap-1">
                  <h4 class="font-medium">Hover Card</h4>
                  <p>This hover card appears on the #{side} side of the trigger.</p>
                </div>
                """
              ]
            }
          end
      }
    ]
  end
end
