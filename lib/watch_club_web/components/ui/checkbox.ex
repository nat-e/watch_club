defmodule WatchClubWeb.Components.UI.Checkbox do
  @moduledoc """
  Token-driven Watch Club checkbox primitive.
  """

  use Phoenix.Component

  attr :id, :any,
    default: nil,
    doc: "required unless `field` is provided; must be stable across renders"

  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: "true"
  attr :checked, :boolean, default: false
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField, doc: "form field — derives id, name, checked, and errors"

  attr :rest, :global, include: ~w(disabled form autofocus required aria-label aria-labelledby)

  def checkbox(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: Map.get(assigns, :id) || field.id,
      name: field.name,
      checked: Phoenix.HTML.Form.normalize_value("checkbox", field.value),
      errors: errors
    )
    |> checkbox()
  end

  def checkbox(assigns) do
    if is_nil(Map.get(assigns, :id)) do
      raise ArgumentError, """
      Checkbox requires an `id` when no `field` is provided.
      Pass `field={@form[:field]}` to derive it from the form field, or pass a stable explicit `id`.
      """
    end

    ~H"""
    <span
      data-slot="checkbox"
      class={[
        "relative inline-grid size-4 shrink-0 place-items-center rounded-control border border-border bg-surface-inset text-transparent transition-[background-color,border-color,box-shadow,color] outline-none",
        "has-[:checked]:border-primary has-[:checked]:bg-primary has-[:checked]:text-on-primary",
        "has-[:focus-visible]:border-border-focus has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-focus-ring",
        "has-[input[aria-invalid='true']]:border-danger-border has-[input[aria-invalid='true']]:ring-2 has-[input[aria-invalid='true']]:ring-danger-ring",
        "has-[:disabled]:cursor-not-allowed has-[:disabled]:opacity-50",
        @class
      ]}
    >
      <input
        id={@id}
        type="checkbox"
        name={@name}
        value={@value}
        checked={@checked}
        aria-invalid={@errors != [] && "true"}
        class="absolute inset-0 size-full cursor-pointer opacity-0 disabled:cursor-not-allowed"
        {@rest}
      />
      <Lucideicons.check aria-hidden="true" class="pointer-events-none size-3" />
    </span>
    """
  end
end
