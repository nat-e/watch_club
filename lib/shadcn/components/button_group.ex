defmodule Shadcn.Components.ButtonGroup do
  @moduledoc """
  Visually-joined group of related buttons or inputs.

      <.button_group>
        <.button variant="outline">Left</.button>
        <.button variant="outline">Center</.button>
        <.button variant="outline">Right</.button>
      </.button_group>

      <.button_group orientation="vertical">
        <.button variant="outline">Top</.button>
        <.button variant="outline">Middle</.button>
        <.button variant="outline">Bottom</.button>
      </.button_group>

  Adjacent children share borders and round only their outer corners.
  Pair with `<.button_group_text>` for inline labels and
  `<.button_group_separator>` for split buttons.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/button-group.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/button-group
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :orientation, :string, values: ~w(horizontal vertical), default: "horizontal"
  attr :rest, :global

  slot :inner_block, required: true

  def button_group(assigns) do
    ~H"""
    <div
      role="group"
      data-slot="button-group"
      data-orientation={@orientation}
      class={["group/button-group", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def button_group_text(assigns) do
    ~H"""
    <div data-slot="button-group-text" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :orientation, :string, values: ~w(horizontal vertical), default: "vertical"
  attr :rest, :global

  def button_group_separator(assigns) do
    ~H"""
    <div
      role="separator"
      aria-orientation={@orientation}
      data-slot="button-group-separator"
      data-orientation={@orientation}
      class={@class}
      {@rest}
    />
    """
  end
end
