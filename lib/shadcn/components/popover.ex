defmodule Shadcn.Components.Popover do
  @moduledoc """
  Lightweight popover anchored to a trigger.

      <.popover id="profile-pop">
        <:trigger><.button variant="outline">@nbarraille</.button></:trigger>
        <:title>Nathan Barraillé</:title>
        <:description>Joined April 2026</:description>
      </.popover>

      <.popover id="filters" side="bottom" align="end">
        <:trigger><.button>Filters</.button></:trigger>
        <p>Filter controls go here.</p>
      </.popover>

  Built like `<.dropdown_menu>` (same positioning hook, no portaling
  beyond moving content to `<body>` to escape transform/filter ancestors).

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/popover.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/popover
  Radix doc: https://www.radix-ui.com/primitives/docs/components/popover
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :side, :string, values: ~w(top right bottom left), default: "bottom"
  attr :align, :string, values: ~w(start center end), default: "center"
  attr :side_offset, :integer, default: 4
  attr :align_offset, :integer, default: 0
  attr :rest, :global

  slot :trigger, required: true

  slot :title do
    attr :class, :any
  end

  slot :description do
    attr :class, :any
  end

  slot :inner_block

  def popover(assigns) do
    ~H"""
    <div
      id={@id}
      data-slot="popover"
      data-state="closed"
      data-side={@side}
      data-align={@align}
      data-side-offset={@side_offset}
      data-align-offset={@align_offset}
      phx-hook="PopoverHook"
      class={["group/popover", @class]}
      {@rest}
    >
      <div data-slot="popover-trigger">
        {render_slot(@trigger)}
      </div>
      <div
        id={"#{@id}-content"}
        data-slot="popover-content"
        data-state="closed"
        role="dialog"
      >
        <div :if={@title != [] or @description != []} data-slot="popover-header">
          <div :for={t <- @title} data-slot="popover-title" class={t[:class]}>
            {render_slot(t)}
          </div>
          <p :for={d <- @description} data-slot="popover-description" class={d[:class]}>
            {render_slot(d)}
          </p>
        </div>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
