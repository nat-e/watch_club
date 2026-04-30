defmodule Shadcn.Components.Toggle do
  @moduledoc """
  Two-state on/off button. Use `pressed` to render the on state.

      <.toggle phx-click="toggle_bold" pressed={@bold}>
        <Lucideicons.bold />
      </.toggle>

      <.toggle variant="outline" size="sm" pressed>
        <Lucideicons.italic />
        Italic
      </.toggle>

  Renders a `<button aria-pressed>`. State is driven by the caller — wire
  it up via `phx-click` and update the `pressed` assign on click. For
  multiple-toggle selection, see `<.toggle_group>`.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/toggle.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/toggle
  Radix doc: https://www.radix-ui.com/primitives/docs/components/toggle
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(default outline), default: "default"
  attr :size, :string, values: ~w(sm default lg), default: "default"
  attr :pressed, :boolean, default: false
  attr :rest, :global, include: ~w(disabled form name value autofocus)

  slot :inner_block, required: true

  def toggle(assigns) do
    ~H"""
    <button
      type="button"
      data-slot="toggle"
      data-variant={@variant}
      data-size={@size}
      data-state={if @pressed, do: "on", else: "off"}
      aria-pressed={if @pressed, do: "true", else: "false"}
      class={["group/toggle", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
