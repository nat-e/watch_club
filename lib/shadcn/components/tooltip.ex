defmodule Shadcn.Components.Tooltip do
  @moduledoc """
  Brief label that appears on hover/focus of a trigger.

      <.tooltip id="save-tip">
        <:trigger><.button variant="outline">Save</.button></:trigger>
        Save changes (⌘S)
      </.tooltip>

      <.tooltip id="info" side="right">
        <:trigger>
          <.button variant="ghost" size="icon"><Lucideicons.info /></.button>
        </:trigger>
        More info
      </.tooltip>

  Mirrors the slot layout of `<.hover_card>` and `<.popover>`: the
  trigger goes in the `<:trigger>` slot, the tooltip text/content in the
  default inner block.

  Ported from Shadcn on 2026-04-29
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/tooltip.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/tooltip
  Radix doc: https://www.radix-ui.com/primitives/docs/components/tooltip
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :side, :string, values: ~w(top right bottom left), default: "top"
  attr :align, :string, values: ~w(start center end), default: "center"
  attr :side_offset, :integer, default: 4
  attr :delay, :integer, default: 0
  attr :rest, :global

  slot :trigger, required: true
  slot :inner_block, required: true

  def tooltip(assigns) do
    ~H"""
    <div
      id={@id}
      data-slot="tooltip"
      data-state="closed"
      data-side={@side}
      data-align={@align}
      data-side-offset={@side_offset}
      data-delay={@delay}
      phx-hook="TooltipHook"
      class={["group/tooltip", @class]}
      {@rest}
    >
      <span data-slot="tooltip-trigger">
        {render_slot(@trigger)}
      </span>
      <div
        id={"#{@id}-content"}
        data-slot="tooltip-content"
        data-state="closed"
        role="tooltip"
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
