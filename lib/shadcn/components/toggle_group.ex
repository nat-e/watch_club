defmodule Shadcn.Components.ToggleGroup do
  @moduledoc """
  Group of related two-state buttons. Single or multiple selection.

      <.toggle_group value="bold">
        <:item value="bold"><Lucideicons.bold /></:item>
        <:item value="italic"><Lucideicons.italic /></:item>
        <:item value="underline"><Lucideicons.underline /></:item>
      </.toggle_group>

      <.toggle_group type="multiple" value={["bold", "italic"]} variant="outline">
        <:item value="bold"><Lucideicons.bold /></:item>
        <:item value="italic"><Lucideicons.italic /></:item>
        <:item value="underline"><Lucideicons.underline /></:item>
      </.toggle_group>

  State is driven by the caller — wire it up via `phx-click` on the items
  and update `value` on change. `value` is a string for `type="single"`
  and a list of strings for `type="multiple"`.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/toggle-group.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/toggle-group
  Radix doc: https://www.radix-ui.com/primitives/docs/components/toggle-group
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :type, :string, values: ~w(single multiple), default: "single"
  attr :value, :any, default: nil
  attr :variant, :string, values: ~w(default outline), default: "default"
  attr :size, :string, values: ~w(sm default lg), default: "default"
  attr :spacing, :integer, default: 0
  attr :orientation, :string, values: ~w(horizontal vertical), default: "horizontal"
  attr :rest, :global

  slot :item, required: true do
    attr :value, :string, required: true
    attr :disabled, :boolean
    attr :class, :any
    attr :rest, :any
  end

  def toggle_group(assigns) do
    ~H"""
    <div
      data-slot="toggle-group"
      data-variant={@variant}
      data-size={@size}
      data-spacing={@spacing}
      data-orientation={@orientation}
      role={if @type == "single", do: "radiogroup", else: "group"}
      style={"--watch-club-toggle-group-gap: #{@spacing}"}
      class={["group/toggle-group", @class]}
      {@rest}
    >
      <button
        :for={item <- @item}
        type="button"
        data-slot="toggle-group-item"
        data-variant={@variant}
        data-size={@size}
        data-spacing={@spacing}
        data-state={if item_pressed?(@value, item.value, @type), do: "on", else: "off"}
        aria-pressed={if item_pressed?(@value, item.value, @type), do: "true", else: "false"}
        disabled={item[:disabled]}
        class={["group/toggle", item[:class]]}
      >
        {render_slot(item)}
      </button>
    </div>
    """
  end

  defp item_pressed?(nil, _value, _type), do: false
  defp item_pressed?(values, value, "multiple") when is_list(values), do: value in values
  defp item_pressed?(current, value, "single"), do: to_string(current) == to_string(value)
  defp item_pressed?(_, _, _), do: false
end
