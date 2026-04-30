defmodule Shadcn.Components.AspectRatio do
  @moduledoc """
  Constrains its child to a fixed width-to-height ratio.

      <.aspect_ratio ratio={16 / 9}>
        <img src="/images/banner.png" class="size-full object-cover" />
      </.aspect_ratio>

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/aspect-ratio.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/aspect-ratio
  Radix doc: https://www.radix-ui.com/primitives/docs/utilities/aspect-ratio
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :ratio, :float, default: 1.0
  attr :rest, :global

  slot :inner_block, required: true

  def aspect_ratio(assigns) do
    ~H"""
    <div data-slot="aspect-ratio" style={"aspect-ratio: #{@ratio}"} class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
