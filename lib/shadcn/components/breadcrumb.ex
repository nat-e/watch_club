defmodule Shadcn.Components.Breadcrumb do
  @moduledoc """
  Trail of links indicating the user's location in a hierarchy.

      <.breadcrumb>
        <.breadcrumb_item>
          <.breadcrumb_link href="/">Home</.breadcrumb_link>
        </.breadcrumb_item>
        <.breadcrumb_separator />
        <.breadcrumb_item>
          <.breadcrumb_link navigate={~p"/library"}>Library</.breadcrumb_link>
        </.breadcrumb_item>
        <.breadcrumb_separator />
        <.breadcrumb_item>
          <.breadcrumb_page>Watches</.breadcrumb_page>
        </.breadcrumb_item>
      </.breadcrumb>

  Authors compose the items directly so dynamic / partial trees stay
  readable. The wrapper renders the `<nav>` + `<ol>`; helpers render the
  individual `<li>`, `<a>`, separator, and ellipsis.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/breadcrumb.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/breadcrumb
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def breadcrumb(assigns) do
    ~H"""
    <nav aria-label="breadcrumb" data-slot="breadcrumb" class={@class} {@rest}>
      <ol data-slot="breadcrumb-list">
        {render_slot(@inner_block)}
      </ol>
    </nav>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def breadcrumb_item(assigns) do
    ~H"""
    <li data-slot="breadcrumb-item" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </li>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch method download replace target)
  slot :inner_block, required: true

  def breadcrumb_link(assigns) do
    ~H"""
    <.link data-slot="breadcrumb-link" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def breadcrumb_page(assigns) do
    ~H"""
    <span
      role="link"
      aria-disabled="true"
      aria-current="page"
      data-slot="breadcrumb-page"
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block

  def breadcrumb_separator(assigns) do
    ~H"""
    <li
      role="presentation"
      aria-hidden="true"
      data-slot="breadcrumb-separator"
      class={@class}
      {@rest}
    >
      <%= if @inner_block != [] do %>
        {render_slot(@inner_block)}
      <% else %>
        <Lucideicons.chevron_right />
      <% end %>
    </li>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  def breadcrumb_ellipsis(assigns) do
    ~H"""
    <span
      role="presentation"
      aria-hidden="true"
      data-slot="breadcrumb-ellipsis"
      class={@class}
      {@rest}
    >
      <Lucideicons.ellipsis />
      <span class="sr-only">More</span>
    </span>
    """
  end
end
