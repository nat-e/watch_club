defmodule Shadcn.Components.ContextMenu do
  @moduledoc """
  Right-click contextual menu attached to a region.

      <.context_menu id="row-actions">
        <:trigger>
          <div class="flex h-32 items-center justify-center rounded-md border border-dashed">
            Right-click me
          </div>
        </:trigger>

        <.context_menu_group>
          <.context_menu_item>Back<.context_menu_shortcut>⌘[</.context_menu_shortcut></.context_menu_item>
          <.context_menu_item disabled>Forward</.context_menu_item>
          <.context_menu_item>Reload<.context_menu_shortcut>⌘R</.context_menu_shortcut></.context_menu_item>
        </.context_menu_group>

        <.context_menu_separator />

        <.context_menu_item variant="destructive">Delete</.context_menu_item>
      </.context_menu>

  Reuses the same item styling as `<.dropdown_menu>` and the same
  positioning/dismissal hook pattern, but opens on the `contextmenu`
  event at the cursor position instead of below a trigger.

  Submenus, checkbox items, and radio groups follow the same pattern as
  `<.dropdown_menu>`; see the helper components below.

  Ported from Shadcn on 2026-04-29
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/context-menu.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/context-menu
  Radix doc: https://www.radix-ui.com/primitives/docs/components/context-menu
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  slot :trigger, required: true
  slot :inner_block, required: true

  def context_menu(assigns) do
    ~H"""
    <div
      id={@id}
      data-slot="context-menu"
      data-state="closed"
      phx-hook="ContextMenuHook"
      class={["group/context-menu", @class]}
      {@rest}
    >
      <div data-slot="context-menu-trigger">
        {render_slot(@trigger)}
      </div>
      <div
        id={"#{@id}-content"}
        data-slot="context-menu-content"
        data-state="closed"
        role="menu"
        aria-orientation="vertical"
        tabindex="-1"
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def context_menu_group(assigns) do
    ~H"""
    <div data-slot="context-menu-group" role="group" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(default destructive), default: "default"
  attr :inset, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def context_menu_item(assigns) do
    ~H"""
    <div
      role="menuitem"
      data-slot="context-menu-item"
      data-variant={@variant}
      data-inset={@inset || nil}
      data-disabled={@disabled || nil}
      aria-disabled={@disabled || nil}
      tabindex="-1"
      class={["group/context-menu-item", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :checked, :boolean, default: false
  attr :inset, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def context_menu_checkbox_item(assigns) do
    ~H"""
    <div
      role="menuitemcheckbox"
      data-slot="context-menu-checkbox-item"
      data-state={if @checked, do: "checked", else: "unchecked"}
      data-inset={@inset || nil}
      data-disabled={@disabled || nil}
      aria-checked={if @checked, do: "true", else: "false"}
      aria-disabled={@disabled || nil}
      tabindex="-1"
      class={@class}
      {@rest}
    >
      <span data-slot="context-menu-checkbox-item-indicator" aria-hidden="true">
        <Lucideicons.check :if={@checked} />
      </span>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :value, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def context_menu_radio_group(assigns) do
    ~H"""
    <div
      data-slot="context-menu-radio-group"
      data-value={@value}
      role="group"
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :value, :string, required: true
  attr :checked, :boolean, default: false
  attr :inset, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def context_menu_radio_item(assigns) do
    ~H"""
    <div
      role="menuitemradio"
      data-slot="context-menu-radio-item"
      data-state={if @checked, do: "checked", else: "unchecked"}
      data-value={@value}
      data-inset={@inset || nil}
      data-disabled={@disabled || nil}
      aria-checked={if @checked, do: "true", else: "false"}
      aria-disabled={@disabled || nil}
      tabindex="-1"
      class={@class}
      {@rest}
    >
      <span data-slot="context-menu-radio-item-indicator" aria-hidden="true">
        <Lucideicons.check :if={@checked} />
      </span>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :inset, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def context_menu_label(assigns) do
    ~H"""
    <div
      data-slot="context-menu-label"
      data-inset={@inset || nil}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  def context_menu_separator(assigns) do
    ~H"""
    <div
      data-slot="context-menu-separator"
      role="separator"
      aria-orientation="horizontal"
      class={@class}
      {@rest}
    />
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def context_menu_shortcut(assigns) do
    ~H"""
    <span data-slot="context-menu-shortcut" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :inset, :boolean, default: false
  attr :rest, :global

  slot :trigger, required: true
  slot :inner_block, required: true

  def context_menu_sub(assigns) do
    id = assigns.id || "context-menu-sub-#{System.unique_integer([:positive])}"
    assigns = assign(assigns, :id, id)

    ~H"""
    <div
      id={@id}
      data-slot="context-menu-sub"
      data-state="closed"
      phx-hook="ContextMenuSubHook"
      class={["group/context-menu-sub", @class]}
      {@rest}
    >
      <div
        role="menuitem"
        aria-haspopup="menu"
        aria-expanded="false"
        data-slot="context-menu-sub-trigger"
        data-state="closed"
        data-inset={@inset || nil}
        data-disabled={@disabled || nil}
        aria-disabled={@disabled || nil}
        tabindex="-1"
      >
        {render_slot(@trigger)}
        <Lucideicons.chevron_right data-slot="context-menu-sub-trigger-chevron" />
      </div>
      <div
        id={"#{@id}-content"}
        data-slot="context-menu-sub-content"
        data-state="closed"
        role="menu"
        aria-orientation="vertical"
        tabindex="-1"
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
