defmodule Shadcn.Components.Menubar do
  @moduledoc """
  Horizontal bar of pull-down menus (think classic File / Edit / View).

      <.menubar>
        <.menubar_menu trigger="File">
          <.menubar_item>New</.menubar_item>
          <.menubar_item>Open...</.menubar_item>
          <.menubar_separator />
          <.menubar_item>Save<.menubar_shortcut>⌘S</.menubar_shortcut></.menubar_item>
        </.menubar_menu>
        <.menubar_menu trigger="Edit">
          <.menubar_item>Undo</.menubar_item>
          <.menubar_item>Redo</.menubar_item>
        </.menubar_menu>
      </.menubar>

  Each menu is just a `<.dropdown_menu>` styled as a menubar trigger.
  Hover behavior between siblings (mouse moves from open menu A to
  closed menu B and B opens) is not implemented — keep menus disjoint.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/menubar.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/menubar
  """
  use Phoenix.Component

  import Shadcn.Components.DropdownMenu

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def menubar(assigns) do
    id = assigns.id || "menubar-#{System.unique_integer([:positive])}"
    assigns = assign(assigns, :id, id)

    ~H"""
    <div
      id={@id}
      data-slot="menubar"
      role="menubar"
      phx-hook="MenubarHook"
      class={["group/menubar", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :trigger, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  def menubar_menu(assigns) do
    id = assigns.id || "menubar-menu-#{System.unique_integer([:positive])}"
    assigns = assign(assigns, :id, id)

    ~H"""
    <.dropdown_menu id={@id} class={["menubar-menu-wrapper", @class]} {@rest}>
      <:trigger>
        <button type="button" data-slot="menubar-trigger">{@trigger}</button>
      </:trigger>
      {render_slot(@inner_block)}
    </.dropdown_menu>
    """
  end

  defdelegate menubar_item(assigns), to: Shadcn.Components.DropdownMenu, as: :dropdown_menu_item

  defdelegate menubar_group(assigns), to: Shadcn.Components.DropdownMenu, as: :dropdown_menu_group

  defdelegate menubar_separator(assigns),
    to: Shadcn.Components.DropdownMenu,
    as: :dropdown_menu_separator

  defdelegate menubar_shortcut(assigns),
    to: Shadcn.Components.DropdownMenu,
    as: :dropdown_menu_shortcut

  defdelegate menubar_label(assigns), to: Shadcn.Components.DropdownMenu, as: :dropdown_menu_label

  defdelegate menubar_checkbox_item(assigns),
    to: Shadcn.Components.DropdownMenu,
    as: :dropdown_menu_checkbox_item

  defdelegate menubar_radio_group(assigns),
    to: Shadcn.Components.DropdownMenu,
    as: :dropdown_menu_radio_group

  defdelegate menubar_radio_item(assigns),
    to: Shadcn.Components.DropdownMenu,
    as: :dropdown_menu_radio_item

  defdelegate menubar_sub(assigns), to: Shadcn.Components.DropdownMenu, as: :dropdown_menu_sub
end
