defmodule Shadcn.Components.Switch do
  @moduledoc """
  On/off toggle switch — a styled checkbox.

      <.switch name="notifications" />
      <.switch name="dark_mode" checked />
      <.switch field={@form[:public]} size="sm" />

  Renders a real `<input type="checkbox">` so it integrates with native form
  submission and `Phoenix.HTML.FormField`. The visible track and thumb are
  CSS-styled siblings driven by `:checked` / `:disabled` on the input.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/switch.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/switch
  Radix doc: https://www.radix-ui.com/primitives/docs/components/switch
  """
  use Phoenix.Component

  attr :id, :any, default: nil
  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: "true"
  attr :checked, :boolean, default: false
  attr :size, :string, values: ~w(sm default), default: "default"
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField, doc: "form field — derives id, name, value, errors"

  attr :rest, :global,
    include: ~w(disabled form autofocus required readonly aria-label aria-labelledby)

  def switch(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: field.name,
      checked: Phoenix.HTML.Form.normalize_value("checkbox", field.value),
      errors: errors
    )
    |> switch()
  end

  def switch(assigns) do
    ~H"""
    <label data-slot="switch" data-size={@size} class={["group/switch", @class]}>
      <input
        type="checkbox"
        id={@id}
        name={@name}
        value={@value}
        checked={@checked}
        aria-invalid={@errors != [] && "true"}
        data-slot="switch-input"
        {@rest}
      />
      <span data-slot="switch-track" aria-hidden="true">
        <span data-slot="switch-thumb" />
      </span>
    </label>
    """
  end
end
