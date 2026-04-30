defmodule Shadcn.Components.NavigationMenu do
  @moduledoc """
  Horizontal site navigation with hover-driven, optionally shared
  viewport for content panels.

      <.navigation_menu id="main-nav">
        <.navigation_menu_item>
          <:trigger>Home</:trigger>
          <ul class="grid w-[400px] gap-2 md:grid-cols-2 p-2">
            <li>
              <.navigation_menu_link href="/docs">Introduction</.navigation_menu_link>
            </li>
          </ul>
        </.navigation_menu_item>
        <.navigation_menu_item>
          <.navigation_menu_link href="/docs" class="navigation-menu-trigger-style">
            Docs
          </.navigation_menu_link>
        </.navigation_menu_item>
      </.navigation_menu>

  Items open on hover after `delay_duration`. Hopping between siblings
  while one is open swaps instantly. With `viewport={true}` (the default)
  all item contents share a single panel that animates between sizes;
  with `viewport={false}` each item's content drops down inline.

  Top-level items that should look like a trigger but navigate
  immediately (no dropdown) wrap a `navigation_menu_link` in a
  `navigation_menu_item` *without* a `:trigger` slot, and add the
  `navigation-menu-trigger-style` class — Shadcn calls this
  `navigationMenuTriggerStyle()`.

  Ported from Shadcn on 2026-04-29
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/navigation-menu.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/navigation-menu
  Radix doc: https://www.radix-ui.com/primitives/docs/components/navigation-menu
  """
  use Phoenix.Component

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :viewport, :boolean, default: true
  attr :delay_duration, :integer, default: 200
  attr :skip_delay_duration, :integer, default: 300
  attr :rest, :global
  slot :inner_block, required: true

  def navigation_menu(assigns) do
    assigns =
      assign_new(assigns, :id, fn ->
        "navigation-menu-#{System.unique_integer([:positive])}"
      end)

    ~H"""
    <nav
      id={@id}
      data-slot="navigation-menu"
      data-viewport={to_string(@viewport)}
      data-state="closed"
      data-delay-duration={@delay_duration}
      data-skip-delay-duration={@skip_delay_duration}
      phx-hook="NavigationMenuHook"
      class={["group/navigation-menu", @class]}
      {@rest}
    >
      <ul data-slot="navigation-menu-list">
        {render_slot(@inner_block)}
      </ul>
      <div :if={@viewport} data-slot="navigation-menu-viewport-wrapper">
        <div data-slot="navigation-menu-viewport" data-state="closed"></div>
      </div>
    </nav>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :trigger do
    attr :class, :any
  end

  slot :inner_block, required: true

  def navigation_menu_item(assigns) do
    ~H"""
    <li data-slot="navigation-menu-item" data-state="closed" class={@class} {@rest}>
      <%= if @trigger != [] do %>
        <button
          type="button"
          data-slot="navigation-menu-trigger"
          data-state="closed"
          aria-expanded="false"
          class={["group/navigation-menu-trigger", trigger_class(@trigger)]}
        >
          {render_slot(@trigger)}
          <svg
            data-slot="navigation-menu-trigger-icon"
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="m6 9 6 6 6-6" />
          </svg>
        </button>
        <div data-slot="navigation-menu-content" data-state="closed" hidden>
          {render_slot(@inner_block)}
        </div>
      <% else %>
        {render_slot(@inner_block)}
      <% end %>
    </li>
    """
  end

  defp trigger_class([%{} = t | _]), do: t[:class]
  defp trigger_class(_), do: nil

  attr :class, :any, default: nil
  attr :active, :boolean, default: false

  attr :rest, :global, include: ~w(href navigate patch method download replace target rel)

  slot :inner_block, required: true

  def navigation_menu_link(assigns) do
    ~H"""
    <.link
      data-slot="navigation-menu-link"
      data-active={if @active, do: "true"}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
