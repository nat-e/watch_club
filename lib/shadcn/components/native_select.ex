defmodule Shadcn.Components.NativeSelect do
  @moduledoc """
  Native HTML `<select>` styled to match the design system.

      <.native_select name="country">
        <option value="">Choose...</option>
        <option value="us">United States</option>
        <option value="ca">Canada</option>
      </.native_select>

      <.native_select field={@form[:tier]} size="sm">
        <option value="free">Free</option>
        <option value="pro">Pro</option>
      </.native_select>

  Uses the browser's native dropdown — accessible, mobile-friendly, no JS.
  For a custom-styled popover with search, see `<.select>` (TODO).

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/native-select.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/native-select
  """
  use Phoenix.Component

  attr :id, :any, default: nil
  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :size, :string, values: ~w(sm default), default: "default"
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField

  attr :rest, :global,
    include: ~w(disabled form autofocus required multiple aria-label aria-labelledby)

  slot :inner_block, required: true

  def native_select(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: field.name,
      value: field.value,
      errors: errors
    )
    |> native_select()
  end

  def native_select(assigns) do
    ~H"""
    <div
      data-slot="native-select-wrapper"
      data-size={@size}
      class={["group/native-select", @class]}
    >
      <select
        id={@id}
        name={@name}
        data-slot="native-select"
        data-size={@size}
        aria-invalid={@errors != [] && "true"}
        {@rest}
      >
        {render_slot(@inner_block, @value)}
      </select>
      <Lucideicons.chevron_down data-slot="native-select-icon" aria-hidden="true" />
    </div>
    """
  end
end
