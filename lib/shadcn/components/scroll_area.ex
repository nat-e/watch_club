defmodule Shadcn.Components.ScrollArea do
  @moduledoc """
  Scrollable region with styled scrollbars (overlay-thin, dark).

      <.scroll_area class="h-72 w-48 rounded-md border">
        <div class="p-4 text-sm">
          <h4 class="mb-4 font-medium">Tags</h4>
          <div :for={tag <- @tags} class="border-b py-2">{tag}</div>
        </div>
      </.scroll_area>

  Falls back to native overflow when unstyled. Uses `overflow: auto` and
  CSS to thin and color the scrollbar; no JS, no virtual scrollers.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/scroll-area.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/scroll-area
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def scroll_area(assigns) do
    ~H"""
    <div data-slot="scroll-area" class={["group/scroll-area", @class]} {@rest}>
      <div data-slot="scroll-area-viewport">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
