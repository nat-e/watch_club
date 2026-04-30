defmodule Shadcn.Components.Separator do
  @moduledoc """
  Visually or semantically divides content.

      <.separator />
      <.separator orientation="vertical" />
      <.separator decorative={false} />

  Set `decorative={false}` when the separator carries semantic meaning (e.g.
  splitting groups in a list); leave the default `true` for purely visual
  dividers, which exposes `role="none"` to assistive tech.

  Ported from Shadcn on 2026-04-28
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/separator.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/separator
  Radix doc: https://www.radix-ui.com/primitives/docs/components/separator
  """
  use Phoenix.Component

  attr :orientation, :string, values: ~w(horizontal vertical), default: "horizontal"
  attr :decorative, :boolean, default: true
  attr :class, :any, default: nil
  attr :rest, :global

  def separator(assigns) do
    ~H"""
    <div
      data-slot="separator"
      data-horizontal={@orientation == "horizontal" || nil}
      data-vertical={@orientation == "vertical" || nil}
      role={if @decorative, do: "none", else: "separator"}
      aria-orientation={if !@decorative and @orientation == "vertical", do: "vertical"}
      class={@class}
      {@rest}
    />
    """
  end
end
