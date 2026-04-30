defmodule Shadcn.Components.Collapsible do
  @moduledoc """
  Single togglable section that shows/hides its content.

      <.collapsible>
        <:trigger>Show more</:trigger>
        Hidden content goes here.
      </.collapsible>

      <.collapsible open>
        <:trigger>Already open</:trigger>
        <p>This is open by default.</p>
      </.collapsible>

  Renders a native `<details>`/`<summary>`. State is managed by the
  browser; no JS required.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/collapsible.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/collapsible
  Radix doc: https://www.radix-ui.com/primitives/docs/components/collapsible
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :open, :boolean, default: false
  attr :rest, :global

  slot :trigger, required: true do
    attr :class, :any
  end

  slot :inner_block, required: true

  def collapsible(assigns) do
    ~H"""
    <details data-slot="collapsible" open={@open} class={@class} {@rest}>
      <summary
        :for={t <- @trigger}
        data-slot="collapsible-trigger"
        class={t[:class]}
      >
        {render_slot(t)}
      </summary>
      <div data-slot="collapsible-content">
        {render_slot(@inner_block)}
      </div>
    </details>
    """
  end
end
