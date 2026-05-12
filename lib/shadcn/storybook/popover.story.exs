defmodule Shadcn.Storybook.Popover do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Popover

  def function, do: &Popover.popover/1

  def imports,
    do: [
      {WatchClubWeb.UI.Button, [button: 1]},
      {Shadcn.Components.Input, [input: 1]},
      {Shadcn.Components.Label, [label: 1]}
    ]

  defp container_template(content) do
    """
    <div class="flex min-h-[280px] items-start justify-center p-12">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  def variations do
    [
      %Variation{
        id: :default,
        attributes: %{id: "pop-default"},
        slots: [
          ~s|<:trigger><.button variant="outline">Open popover</.button></:trigger>|,
          ~s|<:title>Dimensions</:title>|,
          ~s|<:description>Set the dimensions for the layer.</:description>|,
          """
          <div class="grid gap-2">
            <.label for="width">Width</.label>
            <.input id="width" name="width" value="100%" />
          </div>
          """,
          """
          <div class="grid gap-2">
            <.label for="height">Height</.label>
            <.input id="height" name="height" value="25px" />
          </div>
          """
        ]
      },
      %Variation{
        id: :align_end,
        description: "Align end",
        attributes: %{id: "pop-end", align: "end"},
        slots: [
          ~s|<:trigger><.button variant="outline">Settings</.button></:trigger>|,
          ~s|<p>Right-aligned popover content.</p>|
        ]
      }
    ]
  end
end
