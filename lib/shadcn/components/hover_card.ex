defmodule Shadcn.Components.HoverCard do
  @moduledoc """
  Card-like preview that appears on hover (or focus) of a trigger.

      <.hover_card id="user-card">
        <:trigger><a href="#" class="font-medium underline">@nbarraille</a></:trigger>
        <p>Founder of Watch Club. Joined April 2026.</p>
      </.hover_card>

  Like `<.popover>` but driven by hover/focus rather than click.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/hover-card.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/hover-card
  Radix doc: https://www.radix-ui.com/primitives/docs/components/hover-card
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :side, :string, values: ~w(top right bottom left), default: "bottom"
  attr :align, :string, values: ~w(start center end), default: "center"
  attr :side_offset, :integer, default: 4
  attr :align_offset, :integer, default: 0
  attr :open_delay, :integer, default: 700
  attr :close_delay, :integer, default: 300
  attr :rest, :global

  slot :trigger, required: true
  slot :inner_block, required: true

  def hover_card(assigns) do
    ~H"""
    <div
      id={@id}
      data-slot="hover-card"
      data-state="closed"
      data-side={@side}
      data-align={@align}
      data-side-offset={@side_offset}
      data-align-offset={@align_offset}
      data-open-delay={@open_delay}
      data-close-delay={@close_delay}
      phx-hook="HoverCardHook"
      class={["group/hover-card", @class]}
      {@rest}
    >
      <span data-slot="hover-card-trigger">
        {render_slot(@trigger)}
      </span>
      <div
        id={"#{@id}-content"}
        data-slot="hover-card-content"
        data-state="closed"
        role="dialog"
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
