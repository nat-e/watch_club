defmodule Shadcn.Components.RadioGroup do
  @moduledoc """
  Mutually exclusive set of radio buttons.

      <.radio_group name="plan" value="pro">
        <:item value="free">Free</:item>
        <:item value="pro">Pro</:item>
        <:item value="enterprise">Enterprise</:item>
      </.radio_group>

  Renders a real `<input type="radio">` per item so the group integrates
  with native form submission and `Phoenix.HTML.FormField`. The visible
  circle and dot are CSS-styled siblings driven by `:checked` on the input.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/radio-group.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/radio-group
  Radix doc: https://www.radix-ui.com/primitives/docs/components/radio-group
  """
  use Phoenix.Component

  attr :id, :any, default: nil
  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :string, default: nil
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField, doc: "form field — derives id, name, value, errors"
  attr :rest, :global

  slot :item, required: true do
    attr :value, :string, required: true
    attr :disabled, :boolean
    attr :class, :any
  end

  def radio_group(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: field.name,
      value: to_string(field.value),
      errors: errors
    )
    |> radio_group()
  end

  def radio_group(assigns) do
    assigns =
      assign_new(assigns, :id, fn -> "radio-group-#{System.unique_integer([:positive])}" end)

    ~H"""
    <div
      id={@id}
      role="radiogroup"
      data-slot="radio-group"
      aria-invalid={@errors != [] && "true"}
      class={@class}
      {@rest}
    >
      <label
        :for={item <- @item}
        data-slot="radio-group-item-wrapper"
        class={item[:class]}
      >
        <span data-slot="radio-group-item">
          <input
            type="radio"
            name={@name}
            value={item.value}
            checked={to_string(@value) == item.value}
            disabled={item[:disabled]}
            data-slot="radio-group-input"
          />
          <span data-slot="radio-group-indicator" aria-hidden="true">
            <span data-slot="radio-group-dot" />
          </span>
        </span>
        {render_slot(item)}
      </label>
    </div>
    """
  end
end
