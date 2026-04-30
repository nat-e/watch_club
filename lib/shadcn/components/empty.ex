defmodule Shadcn.Components.Empty do
  @moduledoc """
  Empty / zero-state placeholder for lists, tables, search results.

      <.empty>
        <:media variant="icon"><Lucideicons.search /></:media>
        <:title>No results found</:title>
        <:description>Try adjusting your search or filters.</:description>
        <.button>Clear filters</.button>
      </.empty>

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/empty.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/empty
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global

  slot :media do
    attr :variant, :string, values: ~w(default icon)
    attr :class, :any
  end

  slot :title do
    attr :class, :any
  end

  slot :description do
    attr :class, :any
  end

  slot :inner_block

  def empty(assigns) do
    ~H"""
    <div data-slot="empty" class={@class} {@rest}>
      <div data-slot="empty-header">
        <div
          :for={m <- @media}
          data-slot="empty-icon"
          data-variant={m[:variant] || "default"}
          class={m[:class]}
        >
          {render_slot(m)}
        </div>
        <div :for={t <- @title} data-slot="empty-title" class={t[:class]}>
          {render_slot(t)}
        </div>
        <div :for={d <- @description} data-slot="empty-description" class={d[:class]}>
          {render_slot(d)}
        </div>
      </div>
      <div :if={@inner_block != []} data-slot="empty-content">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
