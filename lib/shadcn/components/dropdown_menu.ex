defmodule Shadcn.Components.DropdownMenu do
  @moduledoc """
  Menu of actions or selections triggered by a button.

      <.dropdown_menu id="user-menu">
        <:trigger><.button variant="outline">Open</.button></:trigger>

        <.dropdown_menu_group>
          <.dropdown_menu_label>Account</.dropdown_menu_label>
          <.dropdown_menu_item phx-click="profile">Profile</.dropdown_menu_item>
          <.dropdown_menu_item phx-click="billing">Billing</.dropdown_menu_item>
        </.dropdown_menu_group>

        <.dropdown_menu_separator />

        <.dropdown_menu_item variant="destructive" phx-click="logout">
          Sign out
          <.dropdown_menu_shortcut>⌘Q</.dropdown_menu_shortcut>
        </.dropdown_menu_item>
      </.dropdown_menu>

  Submenus, checkbox items, and radio groups follow the same pattern; see
  the helper components below.

  Differences from the Radix React port:
  - No `Portal` / `Content` wrapper components — the menu body is rendered
    inline as `inner_block` of `<.dropdown_menu>`, position-fixed by
    `dropdown_menu.js`. The hook keeps it visually correct while staying
    a normal LiveView descendant (so server-driven updates work).
  - Trigger is a slot on the root rather than a sibling component.
  - `inset` items align their text past where a leading icon would go,
    matching Radix.

  Ported from Shadcn on 2026-04-28
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/dropdown-menu.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/dropdown-menu
  Radix doc: https://www.radix-ui.com/primitives/docs/components/dropdown-menu
  """
  use Phoenix.Component

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :side, :string, values: ~w(top right bottom left), default: "bottom"
  attr :align, :string, values: ~w(start center end), default: "start"
  attr :side_offset, :integer, default: 4
  attr :align_offset, :integer, default: 0
  attr :rest, :global

  slot :trigger, required: true
  slot :inner_block, required: true

  def dropdown_menu(assigns) do
    id = assigns.id || "dropdown-menu-#{System.unique_integer([:positive])}"
    assigns = assign(assigns, :id, id)

    ~H"""
    <div
      id={@id}
      data-slot="dropdown-menu"
      data-state="closed"
      data-side={@side}
      data-align={@align}
      data-side-offset={@side_offset}
      data-align-offset={@align_offset}
      phx-hook="DropdownMenuHook"
      class={["group/dropdown-menu", @class]}
      {@rest}
    >
      <div data-slot="dropdown-menu-trigger">
        {render_slot(@trigger)}
      </div>
      <div
        id={"#{@id}-content"}
        data-slot="dropdown-menu-content"
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

  def dropdown_menu_group(assigns) do
    ~H"""
    <div data-slot="dropdown-menu-group" role="group" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(default destructive), default: "default"
  attr :inset, :boolean, default: false
  attr :disabled, :boolean, default: false

  attr :rest, :global, include: ~w(href navigate patch method download replace target)

  slot :inner_block, required: true

  def dropdown_menu_item(%{rest: rest} = assigns)
      when is_map_key(rest, :href) or
             is_map_key(rest, :navigate) or
             is_map_key(rest, :patch) do
    ~H"""
    <.link
      role="menuitem"
      data-slot="dropdown-menu-item"
      data-variant={@variant}
      data-inset={@inset || nil}
      data-disabled={@disabled || nil}
      aria-disabled={@disabled || nil}
      tabindex="-1"
      class={["group/dropdown-menu-item", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def dropdown_menu_item(assigns) do
    ~H"""
    <div
      role="menuitem"
      data-slot="dropdown-menu-item"
      data-variant={@variant}
      data-inset={@inset || nil}
      data-disabled={@disabled || nil}
      aria-disabled={@disabled || nil}
      tabindex="-1"
      class={["group/dropdown-menu-item", @class]}
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

  def dropdown_menu_checkbox_item(assigns) do
    ~H"""
    <div
      role="menuitemcheckbox"
      data-slot="dropdown-menu-checkbox-item"
      data-state={if @checked, do: "checked", else: "unchecked"}
      data-inset={@inset || nil}
      data-disabled={@disabled || nil}
      aria-checked={if @checked, do: "true", else: "false"}
      aria-disabled={@disabled || nil}
      tabindex="-1"
      class={@class}
      {@rest}
    >
      <span data-slot="dropdown-menu-checkbox-item-indicator" aria-hidden="true">
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

  def dropdown_menu_radio_group(assigns) do
    ~H"""
    <div
      data-slot="dropdown-menu-radio-group"
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

  def dropdown_menu_radio_item(assigns) do
    ~H"""
    <div
      role="menuitemradio"
      data-slot="dropdown-menu-radio-item"
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
      <span data-slot="dropdown-menu-radio-item-indicator" aria-hidden="true">
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

  def dropdown_menu_label(assigns) do
    ~H"""
    <div
      data-slot="dropdown-menu-label"
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

  def dropdown_menu_separator(assigns) do
    ~H"""
    <div
      data-slot="dropdown-menu-separator"
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

  def dropdown_menu_shortcut(assigns) do
    ~H"""
    <span data-slot="dropdown-menu-shortcut" class={@class} {@rest}>
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

  def dropdown_menu_sub(assigns) do
    id = assigns.id || "dropdown-menu-sub-#{System.unique_integer([:positive])}"
    assigns = assign(assigns, :id, id)

    ~H"""
    <div
      id={@id}
      data-slot="dropdown-menu-sub"
      data-state="closed"
      phx-hook="DropdownMenuSubHook"
      class={["group/dropdown-menu-sub", @class]}
      {@rest}
    >
      <div
        role="menuitem"
        aria-haspopup="menu"
        aria-expanded="false"
        data-slot="dropdown-menu-sub-trigger"
        data-state="closed"
        data-inset={@inset || nil}
        data-disabled={@disabled || nil}
        aria-disabled={@disabled || nil}
        tabindex="-1"
      >
        {render_slot(@trigger)}
        <Lucideicons.chevron_right data-slot="dropdown-menu-sub-trigger-chevron" />
      </div>
      <div
        id={"#{@id}-content"}
        data-slot="dropdown-menu-sub-content"
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
