defmodule Shadcn.Components.Select do
  @moduledoc """
  Custom-styled select with a portaled, anchored option list.

      <.select id="theme" name="theme" placeholder="Theme">
        <.select_item value="light">Light</.select_item>
        <.select_item value="dark">Dark</.select_item>
        <.select_item value="system">System</.select_item>
      </.select>

      <.select id="fruit" name="fruit" placeholder="Select a fruit">
        <.select_group>
          <.select_label>Fruits</.select_label>
          <.select_item value="apple">Apple</.select_item>
          <.select_item value="banana">Banana</.select_item>
        </.select_group>
        <.select_separator />
        <.select_group>
          <.select_label>Vegetables</.select_label>
          <.select_item value="aubergine">Aubergine</.select_item>
          <.select_item value="broccoli">Broccoli</.select_item>
        </.select_group>
      </.select>

  Renders a button trigger and a portaled listbox positioned by `_position.js`.
  A hidden `<input>` carries the value for native form submission, and the
  hook dispatches `input` + `change` events for LiveView form binding.

  Differences from the Radix React port:
  - Composed sub-components (`select_group`, `select_label`, `select_item`,
    `select_separator`) instead of separate React components — same shape,
    Phoenix conventions.
  - The trigger and `SelectValue` are baked into the root: there is no
    separate `<.select_trigger>` slot. The displayed value is hydrated
    client-side from the selected item's text by `select.js`.
  - Content is portaled to `<body>` to escape transformed/contained
    ancestors (avoids `position: fixed` getting trapped by an ancestor's
    transform/backdrop-filter/etc.).
  - Popper-style positioning only — `position="item-aligned"` is not
    supported.
  - RTL is not supported.

  Ported from Shadcn on 2026-04-29
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/select.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/select
  Radix doc: https://www.radix-ui.com/primitives/docs/components/select
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :placeholder, :string, default: "Select..."
  attr :size, :string, values: ~w(sm default), default: "default"
  attr :disabled, :boolean, default: false
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField
  attr :side, :string, values: ~w(top right bottom left), default: "bottom"
  attr :align, :string, values: ~w(start center end), default: "start"
  attr :side_offset, :integer, default: 4
  attr :align_offset, :integer, default: 0
  attr :rest, :global

  slot :inner_block, required: true

  def select(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: field.name,
      value: to_string(field.value || ""),
      errors: errors
    )
    |> select()
  end

  def select(assigns) do
    ~H"""
    <div
      id={@id}
      data-slot="select"
      data-state="closed"
      data-side={@side}
      data-align={@align}
      data-side-offset={@side_offset}
      data-align-offset={@align_offset}
      data-disabled={@disabled || nil}
      phx-hook="SelectHook"
      class={["group/select", @class]}
      {@rest}
    >
      <input type="hidden" name={@name} value={@value} data-slot="select-input" />
      <button
        type="button"
        data-slot="select-trigger"
        data-size={@size}
        data-placeholder
        data-placeholder-text={@placeholder}
        aria-haspopup="listbox"
        aria-expanded="false"
        aria-invalid={(@errors != [] && "true") || nil}
        disabled={@disabled}
      >
        <span data-slot="select-value">{@placeholder}</span>
        <Lucideicons.chevron_down data-slot="select-trigger-icon" aria-hidden="true" />
      </button>
      <div
        id={"#{@id}-content"}
        data-slot="select-content"
        data-state="closed"
        role="listbox"
        tabindex="-1"
      >
        <div data-slot="select-viewport">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def select_group(assigns) do
    ~H"""
    <div data-slot="select-group" role="group" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def select_label(assigns) do
    ~H"""
    <div data-slot="select-label" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :value, :string, required: true
  attr :class, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def select_item(assigns) do
    ~H"""
    <div
      role="option"
      data-slot="select-item"
      data-value={@value}
      data-disabled={@disabled || nil}
      aria-selected="false"
      aria-disabled={@disabled || nil}
      tabindex="-1"
      class={@class}
      {@rest}
    >
      <span data-slot="select-item-indicator" aria-hidden="true">
        <Lucideicons.check />
      </span>
      <span data-slot="select-item-text">{render_slot(@inner_block)}</span>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  def select_separator(assigns) do
    ~H"""
    <div
      data-slot="select-separator"
      role="separator"
      aria-orientation="horizontal"
      class={@class}
      {@rest}
    />
    """
  end
end
