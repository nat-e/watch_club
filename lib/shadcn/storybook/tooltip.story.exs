defmodule Shadcn.Storybook.Tooltip do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Tooltip

  def function, do: &Tooltip.tooltip/1
  def imports, do: [{WatchClubWeb.UI.Button, [button: 1]}, {Lucideicons, [info: 1]}]

  defp container_template(content) do
    """
    <div class="flex min-h-[160px] items-center justify-center p-12">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        description: ~s|Hover the trigger — matches the shadcn doc demo|,
        attributes: %{id: "tip-default"},
        slots: [
          ~s|<:trigger><.button variant="outline">Hover</.button></:trigger>|,
          ~s|Add to library|
        ]
      },
      %VariationGroup{
        id: :sides,
        description: "Positioning — one tooltip per side",
        template: """
        <div class="flex items-center gap-8 p-12">
          <.psb-variation-group/>
        </div>
        """,
        variations:
          for s <- ~w(top right bottom left) do
            %Variation{
              id: String.to_atom(s),
              attributes: %{id: "tip-side-#{s}", side: s},
              slots: [
                ~s|<:trigger><.button variant="outline">#{String.capitalize(s)}</.button></:trigger>|,
                "On #{s}"
              ]
            }
          end
      },
      %Variation{
        id: :icon_only,
        description: "Icon-only trigger with a 200ms delay before opening",
        attributes: %{id: "tip-info", delay: 200},
        slots: [
          ~s|<:trigger><.button variant="ghost" size="icon" aria-label="Info"><Lucideicons.info /></.button></:trigger>|,
          ~s|More information|
        ]
      },
      %Variation{
        id: :rich_content,
        description: "Inner block can hold structured markup",
        attributes: %{id: "tip-rich"},
        slots: [
          ~s|<:trigger><.button variant="outline">Shortcut</.button></:trigger>|,
          ~s|<span>Save</span><span class="text-muted-foreground">⌘S</span>|
        ]
      },
      %Variation{
        id: :long_text,
        description: "Long text wraps within the max-w-xs content box",
        attributes: %{id: "tip-long"},
        slots: [
          ~s|<:trigger><.button variant="outline">Hover for details</.button></:trigger>|,
          "This action permanently deletes the selected items. You will not be able to recover them after confirmation."
        ]
      }
    ]
  end
end
