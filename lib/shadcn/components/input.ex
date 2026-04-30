defmodule Shadcn.Components.Input do
  @moduledoc """
  Single-line form input. Renders a native `<input>` for any type
  (text, email, password, file, number, etc.) with consistent styling,
  focus, disabled, and `aria-invalid` states.

      <.input name="email" type="email" placeholder="you@example.com" />
      <.input name="password" type="password" required />
      <.input name="avatar" type="file" accept="image/*" />
      <.input name="title" aria-invalid="true" />

  Or pass a `Phoenix.HTML.FormField` via `field` to derive `id`, `name`, and
  `value` from the form:

      <.input field={@form[:email]} type="email" />

  Pair with `<.label>` for accessible form fields.

  Ported from Shadcn on 2026-04-27
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/input.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/input
  """
  use Phoenix.Component

  attr :id, :any, default: nil
  attr :class, :any, default: nil
  attr :type, :string, default: "text"
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField, doc: "form field — derives id, name, value, errors"

  attr :rest, :global,
    include:
      ~w(accept autocomplete capture disabled form list max maxlength min minlength multiple pattern placeholder readonly required size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: field.name,
      value: field.value,
      errors: errors
    )
    |> input()
  end

  def input(assigns) do
    ~H"""
    <input
      id={@id}
      type={@type}
      name={@name}
      value={Phoenix.HTML.Form.normalize_value(@type, @value)}
      aria-invalid={@errors != [] && "true"}
      data-slot="input"
      class={@class}
      {@rest}
    />
    """
  end
end
