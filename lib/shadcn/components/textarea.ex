defmodule Shadcn.Components.Textarea do
  @moduledoc """
  Multi-line text input. Auto-grows with `field-sizing: content`.

      <.textarea name="message" placeholder="Type your message here..." />
      <.textarea field={@form[:bio]} rows={4} />

  Pair with `<.label>` for accessible form fields.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/textarea.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/textarea
  """
  use Phoenix.Component

  attr :id, :any, default: nil
  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField, doc: "form field — derives id, name, value, errors"

  attr :rest, :global,
    include:
      ~w(autocomplete autofocus cols dirname disabled form maxlength minlength placeholder readonly required rows wrap)

  def textarea(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: field.name,
      value: field.value,
      errors: errors
    )
    |> textarea()
  end

  def textarea(assigns) do
    ~H"""
    <textarea
      id={@id}
      name={@name}
      aria-invalid={@errors != [] && "true"}
      data-slot="textarea"
      class={@class}
      {@rest}
    >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
    """
  end
end
