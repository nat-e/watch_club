defmodule Shadcn.Components.Badge do
  @moduledoc """
  Small label for status, counts, or category tags.

  Renders a `<span>` by default. Renders a `<.link>` when `href`, `navigate`,
  or `patch` is passed (the equivalent of shadcn's `asChild` + Link pattern),
  so the link-only `:hover` variant styling activates.

      <.badge>New</.badge>
      <.badge variant="destructive">Error</.badge>
      <.badge variant="outline" navigate={~p"/inbox"}>5 unread</.badge>
      <.badge>
        <Lucideicons.check />
        Verified
      </.badge>

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/badge.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/badge
  """
  use Phoenix.Component

  attr :class, :any, default: nil

  attr :variant, :string,
    values: ~w(default secondary destructive outline ghost link),
    default: "default"

  attr :rest, :global, include: ~w(href navigate patch method download replace target)

  slot :inner_block, required: true

  def badge(%{rest: rest} = assigns)
      when is_map_key(rest, :href) or
             is_map_key(rest, :navigate) or
             is_map_key(rest, :patch) do
    ~H"""
    <.link
      data-slot="badge"
      data-variant={@variant}
      class={["group/badge", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def badge(assigns) do
    ~H"""
    <span
      data-slot="badge"
      data-variant={@variant}
      class={["group/badge", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end
end
