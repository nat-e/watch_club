defmodule Shadcn.Components.Checkbox do
  @moduledoc """
  Boolean checkbox.

      <.checkbox name="terms" />
      <.checkbox field={@form[:public]} checked />

  Renders a real `<input type="checkbox">` (visually hidden) so it
  integrates with native form submission and `Phoenix.HTML.FormField`. The
  visible square and check are CSS-styled siblings driven by `:checked` /
  `:disabled` on the input.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/checkbox.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/checkbox
  Radix doc: https://www.radix-ui.com/primitives/docs/components/checkbox
  """
  use Phoenix.Component

  attr :id, :any, default: nil
  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: "true"
  attr :checked, :boolean, default: false
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField, doc: "form field — derives id, name, value, errors"

  attr :rest, :global,
    include: ~w(disabled form autofocus required readonly aria-label aria-labelledby)

  def checkbox(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: field.name,
      checked: Phoenix.HTML.Form.normalize_value("checkbox", field.value),
      errors: errors
    )
    |> checkbox()
  end

  def checkbox(assigns) do
    ~H"""
    <label data-slot="checkbox" class={["group/checkbox", @class]}>
      <input
        type="checkbox"
        id={@id}
        name={@name}
        value={@value}
        checked={@checked}
        aria-invalid={@errors != [] && "true"}
        data-slot="checkbox-input"
        {@rest}
      />
      <span data-slot="checkbox-indicator" aria-hidden="true">
        <Lucideicons.check />
      </span>
    </label>
    """
  end
end
