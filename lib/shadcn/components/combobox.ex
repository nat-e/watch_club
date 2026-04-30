defmodule Shadcn.Components.Combobox do
  @moduledoc """
  Searchable list with single or multi-select. Type to filter, click or
  Enter to pick. Mirrors shadcn's Base-UI-backed Combobox parts.

      <.combobox id="cb" name="framework">
        <.combobox_input placeholder="Select a framework" />
        <.combobox_content>
          <.combobox_empty>No items found.</.combobox_empty>
          <.combobox_list>
            <.combobox_item value="next.js">Next.js</.combobox_item>
            <.combobox_item value="sveltekit">SvelteKit</.combobox_item>
          </.combobox_list>
        </.combobox_content>
      </.combobox>

  Multi-select uses `<.combobox_chips>`/`<.combobox_chip>` instead of
  `<.combobox_input>`. The custom-trigger variant pairs `<.combobox_trigger>`
  with `show_trigger={false}` on a `<.combobox_input>` placed inside the
  popup.

  Differences from the upstream React port:
  - No render-prop list (`<ComboboxList>{(item) => …}`). Items are rendered
    directly as children — Phoenix templates aren't reactive, so virtualization
    isn't relevant here.
  - No `useComboboxAnchor` hook. The popup auto-anchors to whichever input
    surface is present (`<.combobox_input>` or `<.combobox_chips>`).
  - `items` / `defaultValue` / `itemToStringValue` props are absent: items
    come from the rendered DOM, default value comes from the `value` attr,
    and the form value is the item's `value` attr verbatim.

  Ported from Shadcn on 2026-04-29
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/combobox.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/combobox
  Base UI doc: https://base-ui.com/react/components/combobox
  """
  use Phoenix.Component

  import Shadcn.Components.InputGroup

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :multiple, :boolean, default: false
  attr :auto_highlight, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField
  attr :rest, :global

  slot :inner_block, required: true

  def combobox(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: field.name,
      value: normalize_field_value(field.value, assigns.multiple),
      errors: errors
    )
    |> combobox()
  end

  def combobox(assigns) do
    values = to_value_list(assigns.value)

    assigns =
      assigns
      |> assign(:values, values)
      |> assign(:initial_json, Jason.encode!(values))

    ~H"""
    <div
      id={@id}
      data-slot="combobox"
      data-state="closed"
      data-multiple={@multiple || nil}
      data-auto-highlight={@auto_highlight || nil}
      data-disabled={@disabled || nil}
      data-invalid={(@errors != [] && "true") || nil}
      data-initial-value={@initial_json}
      phx-hook="ComboboxHook"
      class={["group/combobox", @class]}
      {@rest}
    >
      <input
        :if={@name && !@multiple}
        type="hidden"
        name={@name}
        value={List.first(@values) || ""}
        data-slot="combobox-form-input"
      />
      <input
        :for={v <- @values}
        :if={@name && @multiple}
        type="hidden"
        name={"#{@name}[]"}
        value={v}
        data-slot="combobox-form-input"
      />
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :placeholder, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :show_trigger, :boolean, default: true
  attr :show_clear, :boolean, default: false
  attr :rest, :global, include: ~w(aria-invalid)

  slot :inner_block

  def combobox_input(assigns) do
    ~H"""
    <div
      data-slot="combobox-input"
      data-show-trigger={@show_trigger || nil}
      data-show-clear={@show_clear || nil}
      class={@class}
    >
      <.input_group class="w-auto">
        {render_slot(@inner_block)}
        <.input_group_input
          placeholder={@placeholder}
          disabled={@disabled}
          autocomplete="off"
          {@rest}
        />
        <.input_group_addon align="inline-end">
          <.input_group_button
            :if={@show_trigger}
            class="combobox-trigger-toggle"
            tabindex="-1"
            disabled={@disabled}
          >
            <Lucideicons.chevron_down data-slot="combobox-trigger-icon" />
          </.input_group_button>
          <.combobox_clear :if={@show_clear} disabled={@disabled} />
        </.input_group_addon>
      </.input_group>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :placeholder, :string, default: nil
  attr :rest, :global

  slot :inner_block

  def combobox_value(assigns) do
    ~H"""
    <span
      data-slot="combobox-value"
      data-placeholder-text={@placeholder}
      class={@class}
      {@rest}
    >
      {if @inner_block != [], do: render_slot(@inner_block), else: @placeholder}
    </span>
    """
  end

  attr :class, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global

  slot :inner_block

  def combobox_trigger(assigns) do
    ~H"""
    <button
      type="button"
      data-slot="combobox-trigger-button"
      data-placeholder="true"
      aria-haspopup="listbox"
      disabled={@disabled}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
      <Lucideicons.chevron_down data-slot="combobox-trigger-icon" aria-hidden="true" />
    </button>
    """
  end

  attr :class, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def combobox_clear(assigns) do
    ~H"""
    <.input_group_button
      tabindex="-1"
      hidden
      disabled={@disabled}
      class={["combobox-clear-button", @class]}
      {@rest}
    >
      <Lucideicons.x />
    </.input_group_button>
    """
  end

  attr :class, :any, default: nil
  attr :side, :string, values: ~w(top right bottom left), default: "bottom"
  attr :align, :string, values: ~w(start center end), default: "start"
  attr :side_offset, :integer, default: 6
  attr :align_offset, :integer, default: 0
  attr :rest, :global

  slot :inner_block, required: true

  def combobox_content(assigns) do
    ~H"""
    <div
      data-slot="combobox-content"
      data-state="closed"
      data-side={@side}
      data-align={@align}
      data-side-offset={@side_offset}
      data-align-offset={@align_offset}
      role="presentation"
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def combobox_list(assigns) do
    ~H"""
    <div data-slot="combobox-list" role="listbox" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :value, :string, required: true
  attr :label, :string, default: nil
  attr :class, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global

  slot :inner_block, required: true

  def combobox_item(assigns) do
    ~H"""
    <div
      role="option"
      data-slot="combobox-item"
      data-value={@value}
      data-label={@label}
      data-disabled={@disabled || nil}
      aria-disabled={@disabled || nil}
      aria-selected="false"
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
      <span data-slot="combobox-item-indicator" aria-hidden="true">
        <Lucideicons.check />
      </span>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def combobox_group(assigns) do
    ~H"""
    <div data-slot="combobox-group" role="group" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def combobox_label(assigns) do
    ~H"""
    <div data-slot="combobox-label" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def combobox_empty(assigns) do
    ~H"""
    <div data-slot="combobox-empty" hidden class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  def combobox_separator(assigns) do
    ~H"""
    <div data-slot="combobox-separator" role="separator" class={@class} {@rest} />
    """
  end

  attr :class, :any, default: nil
  attr :placeholder, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :show_remove, :boolean, default: true
  attr :rest, :global, include: ~w(aria-invalid)

  def combobox_chips(assigns) do
    ~H"""
    <div
      data-slot="combobox-chips"
      data-disabled={@disabled || nil}
      class={@class}
      {@rest}
    >
      <div data-slot="combobox-chips-list" />
      <input
        type="text"
        data-slot="combobox-chips-input"
        placeholder={@placeholder}
        disabled={@disabled}
        autocomplete="off"
      />
      <template data-slot="combobox-chip-template" data-show-remove={@show_remove || nil}>
        <span data-slot="combobox-chip">
          <span data-slot="combobox-chip-label"></span>
          <button
            :if={@show_remove}
            type="button"
            data-slot="combobox-chip-remove"
            aria-label="Remove"
            tabindex="-1"
          >
            <Lucideicons.x />
          </button>
        </span>
      </template>
    </div>
    """
  end

  defp normalize_field_value(value, true) when is_list(value), do: value
  defp normalize_field_value(nil, true), do: []
  defp normalize_field_value(value, true), do: [to_string(value)]
  defp normalize_field_value(nil, false), do: nil
  defp normalize_field_value(value, false), do: to_string(value)

  defp to_value_list(nil), do: []
  defp to_value_list(""), do: []
  defp to_value_list(value) when is_list(value), do: Enum.map(value, &to_string/1)
  defp to_value_list(value), do: [to_string(value)]
end
