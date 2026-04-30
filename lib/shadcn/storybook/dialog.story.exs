defmodule Shadcn.Storybook.Dialog do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Dialog

  def function, do: &Dialog.dialog/1

  def imports,
    do: [
      {Shadcn.Components.Button, [button: 1]},
      {Shadcn.Components.Input, [input: 1]},
      {Shadcn.Components.Label, [label: 1]}
    ]

  @lorem """
  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod \
  tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim \
  veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea \
  commodo consequat. Duis aute irure dolor in reprehenderit in voluptate \
  velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat \
  cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id \
  est laborum.\
  """

  defp scrollable_paragraphs do
    body =
      1..10
      |> Enum.map_join("\n", fn _ -> ~s|<p class="mb-4 leading-normal">#{@lorem}</p>| end)

    ~s|<div class="-mx-6 max-h-[50vh] overflow-y-auto px-6">#{body}</div>|
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "Edit profile — labelled inputs, Cancel + Save changes",
        attributes: %{id: "dialog-default"},
        slots: [
          ~s|<:trigger><.button variant="outline">Open Dialog</.button></:trigger>|,
          ~s|<:title>Edit profile</:title>|,
          ~s|<:description>Make changes to your profile here. Click save when you're done.</:description>|,
          """
          <div class="flex flex-col gap-4">
            <div class="grid gap-2">
              <.label for="dlg-name">Name</.label>
              <.input id="dlg-name" name="name" value="Pedro Duarte" />
            </div>
            <div class="grid gap-2">
              <.label for="dlg-username">Username</.label>
              <.input id="dlg-username" name="username" value="@peduarte" />
            </div>
          </div>
          """,
          """
          <:footer>
            <.button variant="outline" data-dialog-close>Cancel</.button>
            <.button type="submit">Save changes</.button>
          </:footer>
          """
        ]
      },
      %Variation{
        id: :custom_close,
        description: "Custom close — single footer button replaces the default close control",
        attributes: %{id: "dialog-custom-close"},
        slots: [
          ~s|<:trigger><.button variant="outline">Share</.button></:trigger>|,
          ~s|<:title>Share link</:title>|,
          ~s|<:description>Anyone who has this link will be able to view this.</:description>|,
          """
          <div class="flex items-center gap-2">
            <div class="grid flex-1 gap-2">
              <.label for="dlg-link" class="sr-only">Link</.label>
              <.input id="dlg-link" name="link" value="https://ui.shadcn.com/docs/installation" readonly />
            </div>
          </div>
          """,
          ~s|<:footer class="sm:justify-start"><.button data-dialog-close>Close</.button></:footer>|
        ]
      },
      %Variation{
        id: :no_close,
        description: ~s|show_close={false} — hides the top-right close icon|,
        attributes: %{id: "dialog-no-close", show_close: false},
        slots: [
          ~s|<:trigger><.button variant="outline">No Close Button</.button></:trigger>|,
          ~s|<:title>No Close Button</:title>|,
          ~s|<:description>This dialog doesn't have a close button in the top-right corner.</:description>|
        ]
      },
      %Variation{
        id: :sticky_footer,
        description: "Sticky footer — body scrolls, footer stays visible",
        attributes: %{id: "dialog-sticky-footer"},
        slots: [
          ~s|<:trigger><.button variant="outline">Sticky Footer</.button></:trigger>|,
          ~s|<:title>Sticky Footer</:title>|,
          ~s|<:description>This dialog has a sticky footer that stays visible while the content scrolls.</:description>|,
          scrollable_paragraphs(),
          ~s|<:footer><.button variant="outline" data-dialog-close>Close</.button></:footer>|
        ]
      },
      %Variation{
        id: :scrollable_content,
        description: "Scrollable content — long body scrolls, header stays in view",
        attributes: %{id: "dialog-scrollable-content"},
        slots: [
          ~s|<:trigger><.button variant="outline">Scrollable Content</.button></:trigger>|,
          ~s|<:title>Scrollable Content</:title>|,
          ~s|<:description>This is a dialog with scrollable content.</:description>|,
          scrollable_paragraphs()
        ]
      }
    ]
  end
end
