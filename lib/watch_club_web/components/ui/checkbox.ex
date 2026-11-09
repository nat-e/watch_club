defmodule WatchClubWeb.Components.UI.Checkbox do
  @moduledoc """
  Token-driven Watch Club checkbox primitive.
  """

  use Phoenix.Component

  import WatchClubWeb.Components.UI.Layout

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
        "relative inline-grid size-4 shrink-0 place-items-center rounded-sm border border-border-control bg-surface-inset text-transparent transition-[background-color,border-color,box-shadow,color] outline-none",
        "has-checked:border-primary has-checked:bg-primary has-checked:text-on-primary",
        "has-focus-visible:border-border-focus has-focus-visible:ring-2 has-focus-visible:ring-focus-ring",
        "has-[input[aria-invalid='true']]:not-has-focus-visible:border-danger-border has-[input[aria-invalid='true']]:not-has-focus-visible:ring-2 has-[input[aria-invalid='true']]:not-has-focus-visible:ring-danger-ring",
        "has-disabled:cursor-not-allowed has-disabled:opacity-40",
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

  attr :field, Phoenix.HTML.FormField, doc: "form field — derives id, name, checked, and errors"
  attr :options, :list, required: true, doc: "List of all potential options"
  attr :to_value, {:fun, 1}, required: true, doc: "A function to extract the value of an option"

  attr :disabled?, {:fun, 1},
    default: nil,
    doc: "A function to decide whether an option should be disabled"

  slot :label, required: true

  def checkbox_group(assigns) do
    ~H"""
    <.stack space="related">
      <%!-- Submits an empty list when no option is checked --%>
      <input type="hidden" name={@field.name <> "[]"} value="" />
      <.checkbox_group_item
        :for={option <- @options}
        field={@field}
        option={option}
        label={@label}
        value={@to_value.(option)}
        disabled?={@disabled? && @disabled?.(option)}
      />
    </.stack>
    """
  end

  defp checkbox_group_item(assigns) do
    ~H"""
    <label
      for={"#{@field.id}-#{@value}"}
      class={[
        "flex h-control-lg w-full items-center justify-between rounded-card border border-border-subtle bg-surface p-related text-sm text-text",
        @disabled? && "cursor-not-allowed opacity-40"
      ]}
    >
      {render_slot(@label, @option)}
      <.checkbox
        id={"#{@field.id}-#{@value}"}
        name={@field.name <> "[]"}
        value={@value}
        checked={@value in @field.value}
        disabled={@disabled?}
      />
    </label>
    """
  end
end
