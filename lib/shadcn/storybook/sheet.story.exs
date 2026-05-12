defmodule Shadcn.Storybook.Sheet do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Sheet

  def function, do: &Sheet.sheet/1

  def imports,
    do: [
      {WatchClubWeb.UI.Button, [button: 1]},
      {Shadcn.Components.Input, [input: 1]},
      {Shadcn.Components.Label, [label: 1]}
    ]

  def variations do
    [
      %Variation{
        id: :default,
        description: "Edit profile — labelled inputs, Save changes + Close footer",
        attributes: %{id: "sheet-default"},
        slots: [
          ~s|<:trigger><.button variant="outline">Open</.button></:trigger>|,
          ~s|<:title>Edit profile</:title>|,
          ~s|<:description>Make changes to your profile here. Click save when you're done.</:description>|,
          """
          <div class="grid flex-1 auto-rows-min gap-6 px-4">
            <div class="grid gap-3">
              <.label for="sheet-demo-name">Name</.label>
              <.input id="sheet-demo-name" name="name" value="Pedro Duarte" />
            </div>
            <div class="grid gap-3">
              <.label for="sheet-demo-username">Username</.label>
              <.input id="sheet-demo-username" name="username" value="@peduarte" />
            </div>
          </div>
          """,
          """
          <:footer>
            <.button type="submit">Save changes</.button>
            <.button variant="outline" data-sheet-close>Close</.button>
          </:footer>
          """
        ]
      },
      %Variation{
        id: :top,
        description: ~s|side="top" — slides down from the top edge|,
        attributes: %{id: "sheet-top", side: "top"},
        slots: [
          ~s|<:trigger><.button variant="outline">Top</.button></:trigger>|,
          ~s|<:title>Edit profile</:title>|,
          ~s|<:description>Make changes to your profile here. Click save when you're done.</:description>|,
          """
          <:footer>
            <.button type="submit">Save changes</.button>
            <.button variant="outline" data-sheet-close>Cancel</.button>
          </:footer>
          """
        ]
      },
      %Variation{
        id: :right,
        description: ~s|side="right" (default) — slides in from the right edge|,
        attributes: %{id: "sheet-right", side: "right"},
        slots: [
          ~s|<:trigger><.button variant="outline">Right</.button></:trigger>|,
          ~s|<:title>Edit profile</:title>|,
          ~s|<:description>Make changes to your profile here. Click save when you're done.</:description>|,
          """
          <:footer>
            <.button type="submit">Save changes</.button>
            <.button variant="outline" data-sheet-close>Cancel</.button>
          </:footer>
          """
        ]
      },
      %Variation{
        id: :bottom,
        description: ~s|side="bottom" — slides up from the bottom edge|,
        attributes: %{id: "sheet-bottom", side: "bottom"},
        slots: [
          ~s|<:trigger><.button variant="outline">Bottom</.button></:trigger>|,
          ~s|<:title>Edit profile</:title>|,
          ~s|<:description>Make changes to your profile here. Click save when you're done.</:description>|,
          """
          <:footer>
            <.button type="submit">Save changes</.button>
            <.button variant="outline" data-sheet-close>Cancel</.button>
          </:footer>
          """
        ]
      },
      %Variation{
        id: :left,
        description: ~s|side="left" — slides in from the left edge|,
        attributes: %{id: "sheet-left", side: "left"},
        slots: [
          ~s|<:trigger><.button variant="outline">Left</.button></:trigger>|,
          ~s|<:title>Edit profile</:title>|,
          ~s|<:description>Make changes to your profile here. Click save when you're done.</:description>|,
          """
          <:footer>
            <.button type="submit">Save changes</.button>
            <.button variant="outline" data-sheet-close>Cancel</.button>
          </:footer>
          """
        ]
      },
      %Variation{
        id: :no_close,
        description: ~s|show_close={false} — hides the top-right close icon|,
        attributes: %{id: "sheet-no-close", show_close: false},
        slots: [
          ~s|<:trigger><.button variant="outline">Open Sheet</.button></:trigger>|,
          ~s|<:title>No Close Button</:title>|,
          ~s|<:description>This sheet doesn't have a close button in the top-right corner. Click outside to close.</:description>|
        ]
      }
    ]
  end
end
