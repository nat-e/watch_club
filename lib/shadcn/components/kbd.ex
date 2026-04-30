defmodule Shadcn.Components.Kbd do
  @moduledoc """
  Keyboard input or shortcut indicator.

      <.kbd>⌘K</.kbd>

      <.kbd_group>
        <.kbd>Ctrl</.kbd>
        <.kbd>+</.kbd>
        <.kbd>K</.kbd>
      </.kbd_group>

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/kbd.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/kbd
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def kbd(assigns) do
    ~H"""
    <kbd data-slot="kbd" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </kbd>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def kbd_group(assigns) do
    ~H"""
    <kbd data-slot="kbd-group" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </kbd>
    """
  end
end
