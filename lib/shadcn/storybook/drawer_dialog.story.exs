defmodule Shadcn.Storybook.DrawerDialog do
  @moduledoc """
  Responsive recipe — show a `<.dialog>` on `md+` viewports and swap to a
  `<.drawer>` below. Mirrors the "Drawer Dialog" example from the shadcn
  drawer doc, achieved here via Tailwind responsive `hidden` / `contents`
  classes (no JS media-query needed).
  """
  use PhoenixStorybook.Story, :component
  use Phoenix.Component

  import WatchClubWeb.UI.Button
  import Shadcn.Components.Dialog
  import Shadcn.Components.Drawer
  import Shadcn.Components.Input
  import Shadcn.Components.Label

  def function, do: &__MODULE__.responsive_edit_profile/1

  attr :id, :string, required: true

  def responsive_edit_profile(assigns) do
    ~H"""
    <div>
      <div class="hidden md:contents">
        <.dialog id={"#{@id}-dialog"}>
          <:title>Edit profile</:title>
          <:description>Make changes to your profile here. Click save when you're done.</:description>
          <.profile_form id={"#{@id}-dialog"} />
        </.dialog>
      </div>
      <div class="contents md:hidden">
        <.drawer id={"#{@id}-drawer"}>
          <:trigger><.button variant="outline">Edit Profile</.button></:trigger>
          <:title class="text-left">Edit profile</:title>
          <:description class="text-left">
            Make changes to your profile here. Click save when you're done.
          </:description>
          <div class="px-4 pb-4">
            <.profile_form id={"#{@id}-drawer"} />
          </div>
          <:footer class="pt-2">
            <.button data-drawer-close variant="outline">Cancel</.button>
          </:footer>
        </.drawer>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true

  defp profile_form(assigns) do
    ~H"""
    <form class="grid items-start gap-6">
      <div class="grid gap-3">
        <.label for={"#{@id}-email"}>Email</.label>
        <.input type="email" id={"#{@id}-email"} name="email" value="shadcn@example.com" />
      </div>
      <div class="grid gap-3">
        <.label for={"#{@id}-username"}>Username</.label>
        <.input id={"#{@id}-username"} name="username" value="@shadcn" />
      </div>
      <.button type="submit">Save changes</.button>
    </form>
    """
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "Edit Profile — Dialog at md+, Drawer below",
        attributes: %{id: "drawer-dialog-default"}
      }
    ]
  end
end
