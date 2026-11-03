defmodule WatchClubWeb.Components.UI.RadioGroup do
  @moduledoc """
  Token-driven Watch Club radio group primitive.

  Renders native radio inputs so groups integrate with forms, LiveView change
  events, and `Phoenix.HTML.FormField`. Items can provide tooltip content,
  which uses the whole item wrapper as the tooltip trigger.
  """

  use Phoenix.Component

  import WatchClubWeb.Components.UI.Tooltip

  attr :id, :any,
    default: nil,
    doc: "required unless `field` is provided; must be stable across renders"

  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField, doc: "form field — derives id, name, value, and errors"
  attr :rest, :global

  slot :item, required: true do
    attr :value, :any, required: true
    attr :disabled, :boolean
    attr :class, :any
    attr :tooltip, :any
  end

  def radio_group(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: Map.get(assigns, :id) || field.id,
      name: field.name,
      value: Map.get(assigns, :value) || input_value(field.value),
      errors: errors
    )
    |> radio_group()
  end

  def radio_group(assigns) do
    if is_nil(Map.get(assigns, :id)) do
      raise ArgumentError, """
      Radio group requires an `id` when no `field` is provided.
      Pass `field={@form[:field]}` to derive it from the form field, or pass a stable explicit `id`.
      """
    end

    ~H"""
    <div
      id={@id}
      role="radiogroup"
      data-slot="radio-group"
      aria-invalid={@errors != [] && "true"}
      class={["grid w-full gap-related", @class]}
      {@rest}
    >
      <%!-- Submitted when nothing is checked, so the field counts as used and
      shows its errors after a submit, even with no options. Left out when
      every option is disabled: the user can't change the value, so the group
      submits nothing. --%>
      <input
        :if={@item == [] or Enum.any?(@item, &(!&1[:disabled]))}
        type="hidden"
        name={@name}
        value=""
      />

      <%= for item <- @item do %>
        <.tooltip
          :if={item[:tooltip]}
          id={"#{@id}-#{input_value(item.value)}-tooltip"}
          class="contents"
        >
          <:trigger>
            <.radio_group_item
              id={@id}
              name={@name}
              value={@value}
              errors={@errors}
              item={item}
              focusable={item[:disabled]}
            />
          </:trigger>
          {item[:tooltip]}
        </.tooltip>

        <.radio_group_item
          :if={!item[:tooltip]}
          id={@id}
          name={@name}
          value={@value}
          errors={@errors}
          item={item}
        />
      <% end %>
    </div>
    """
  end

  attr :id, :any, required: true
  attr :name, :any, required: true
  attr :value, :any, default: nil
  attr :errors, :list, required: true
  attr :item, :map, required: true
  attr :focusable, :boolean, default: false

  defp radio_group_item(assigns) do
    ~H"""
    <label
      data-slot="radio-group-item-wrapper"
      tabindex={@focusable && "0"}
      class={[
        if @item[:class] do
          "cursor-pointer rounded-control text-sm text-text transition-colors select-none"
        else
          "inline-flex cursor-pointer items-center gap-related rounded-control text-sm text-text transition-colors select-none"
        end,
        "has-disabled:cursor-not-allowed has-disabled:text-text-disabled has-disabled:opacity-40",
        @item[:class]
      ]}
    >
      <span
        data-slot="radio-group-item"
        class={[
          "group/radio-control relative inline-grid size-4 shrink-0 place-items-center rounded-full border border-border-control bg-surface-inset text-transparent transition-[background-color,border-color,box-shadow,color] outline-none",
          "has-checked:border-primary has-checked:bg-primary has-checked:text-on-primary",
          "has-focus-visible:border-border-focus has-focus-visible:ring-2 has-focus-visible:ring-focus-ring",
          "has-[input[aria-invalid='true']]:not-has-focus-visible:border-danger-border has-[input[aria-invalid='true']]:not-has-focus-visible:ring-2 has-[input[aria-invalid='true']]:not-has-focus-visible:ring-danger-ring"
        ]}
      >
        <input
          id={"#{@id}-#{input_value(@item.value)}"}
          type="radio"
          name={@name}
          value={input_value(@item.value)}
          checked={input_value(@value) == input_value(@item.value)}
          disabled={@item[:disabled]}
          aria-invalid={@errors != [] && "true"}
          data-slot="radio-group-input"
          class="absolute inset-0 size-full cursor-pointer opacity-0 disabled:cursor-not-allowed"
        />
        <span
          data-slot="radio-group-indicator"
          aria-hidden="true"
          class="pointer-events-none grid size-full place-items-center opacity-0 transition-opacity group-has-checked/radio-control:opacity-100"
        >
          <span data-slot="radio-group-dot" class="size-2 rounded-full bg-on-primary" />
        </span>
      </span>
      {render_slot(@item)}
    </label>
    """
  end

  defp input_value(nil), do: ""
  defp input_value(value), do: to_string(value)
end
