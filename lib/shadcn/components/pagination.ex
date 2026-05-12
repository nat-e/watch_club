defmodule Shadcn.Components.Pagination do
  @moduledoc """
  Page navigation control.

      <.pagination>
        <.pagination_previous href="?page=1" />
        <.pagination_link href="?page=1">1</.pagination_link>
        <.pagination_link href="?page=2" active>2</.pagination_link>
        <.pagination_link href="?page=3">3</.pagination_link>
        <.pagination_ellipsis />
        <.pagination_link href="?page=10">10</.pagination_link>
        <.pagination_next href="?page=3" />
      </.pagination>

  Author the items directly so partial / dynamic page lists stay readable.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/pagination.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/pagination
  """
  use Phoenix.Component

  import WatchClubWeb.UI.Button

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def pagination(assigns) do
    ~H"""
    <nav role="navigation" aria-label="pagination" data-slot="pagination" class={@class} {@rest}>
      <ul data-slot="pagination-content">
        {render_slot(@inner_block)}
      </ul>
    </nav>
    """
  end

  attr :class, :any, default: nil
  attr :active, :boolean, default: false
  attr :size, :string, values: ~w(sm md icon), default: "icon"
  attr :rest, :global, include: ~w(href navigate patch method download replace target)
  slot :inner_block, required: true

  def pagination_link(assigns) do
    ~H"""
    <li data-slot="pagination-item">
      <.button
        variant={if @active, do: "secondary", else: "ghost"}
        size={@size}
        aria-current={if @active, do: "page"}
        data-slot="pagination-link"
        data-active={@active || nil}
        class={@class}
        {@rest}
      >
        {render_slot(@inner_block)}
      </.button>
    </li>
    """
  end

  attr :class, :any, default: nil
  attr :text, :string, default: "Previous"
  attr :rest, :global, include: ~w(href navigate patch method download replace target)

  def pagination_previous(assigns) do
    ~H"""
    <li data-slot="pagination-item">
      <.button
        variant="ghost"
        size="md"
        aria-label="Go to previous page"
        data-slot="pagination-link"
        class={["pl-2!", @class]}
        {@rest}
      >
        <:icon position="start"><Lucideicons.chevron_left /></:icon>
        <span class="hidden sm:block">{@text}</span>
      </.button>
    </li>
    """
  end

  attr :class, :any, default: nil
  attr :text, :string, default: "Next"
  attr :rest, :global, include: ~w(href navigate patch method download replace target)

  def pagination_next(assigns) do
    ~H"""
    <li data-slot="pagination-item">
      <.button
        variant="ghost"
        size="md"
        aria-label="Go to next page"
        data-slot="pagination-link"
        class={["pr-2!", @class]}
        {@rest}
      >
        <span class="hidden sm:block">{@text}</span>
        <:icon position="end"><Lucideicons.chevron_right /></:icon>
      </.button>
    </li>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  def pagination_ellipsis(assigns) do
    ~H"""
    <li data-slot="pagination-item">
      <span aria-hidden="true" data-slot="pagination-ellipsis" class={@class} {@rest}>
        <Lucideicons.ellipsis />
        <span class="sr-only">More pages</span>
      </span>
    </li>
    """
  end
end
