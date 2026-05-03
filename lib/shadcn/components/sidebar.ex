defmodule Shadcn.Components.Sidebar do
  @moduledoc """
  Composable application sidebar with collapse, off-canvas, floating, and
  inset variants. Supports grouped menus, sub-menus, badges, secondary
  actions, tooltips on collapse, and a mobile slide-in overlay.

      <.sidebar_provider id="app-shell">
        <.sidebar collapsible="icon">
          <:header>
            <.sidebar_menu>
              <.sidebar_menu_item size="lg">
                <:icon><Lucideicons.gallery_horizontal_end /></:icon>
                Watch Club
              </.sidebar_menu_item>
            </.sidebar_menu>
          </:header>

          <.sidebar_group>
            <:label>Application</:label>
            <.sidebar_menu>
              <.sidebar_menu_item href="/" tooltip="Dashboard" active>
                <:icon><Lucideicons.home /></:icon>
                Dashboard
              </.sidebar_menu_item>
              <.sidebar_menu_item href="/inbox" tooltip="Inbox">
                <:icon><Lucideicons.inbox /></:icon>
                Inbox
                <:badge>24</:badge>
              </.sidebar_menu_item>
            </.sidebar_menu>
          </.sidebar_group>

          <:footer>
            <.sidebar_menu>
              <.sidebar_menu_item href="/profile" tooltip="Profile">
                <:icon><Lucideicons.user /></:icon>
                Profile
              </.sidebar_menu_item>
            </.sidebar_menu>
          </:footer>

          <.sidebar_rail />
        </.sidebar>

        <.sidebar_inset>
          <header class="flex h-12 items-center gap-2 border-b px-4">
            <button phx-click={JS.dispatch("wc:sidebar-toggle", to: "#app-shell")}>
              Toggle
            </button>
            <span>Page title</span>
          </header>
          <main>{@inner_content}</main>
        </.sidebar_inset>
      </.sidebar_provider>

  Toggle from anywhere by dispatching a DOM event to the
  `<.sidebar_provider>` element:

      JS.dispatch("wc:sidebar-toggle", to: "#app-shell")
      JS.dispatch("wc:sidebar-open",   to: "#app-shell")
      JS.dispatch("wc:sidebar-close",  to: "#app-shell")

  The rail (`<.sidebar_rail>`) and Cmd/Ctrl+B also toggle. Open state
  persists across navigations via the `sidebar_state` cookie. RTL is
  not supported (project-wide policy).

  Ported from Shadcn on 2026-04-29
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/sidebar.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/sidebar
  """
  use Phoenix.Component

  import Shadcn.Components.Skeleton

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :default_open, :boolean, default: true
  attr :rest, :global

  slot :inner_block, required: true

  def sidebar_provider(assigns) do
    ~H"""
    <div
      id={@id}
      data-slot="sidebar-wrapper"
      data-state={if @default_open, do: "expanded", else: "collapsed"}
      phx-hook="WCSidebarHook"
      class={["group/sidebar-wrapper", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :side, :string, values: ~w(left right), default: "left"
  attr :variant, :string, values: ~w(sidebar floating inset), default: "sidebar"
  attr :collapsible, :string, values: ~w(offcanvas icon none), default: "offcanvas"
  attr :rest, :global

  slot :header
  slot :footer
  slot :inner_block, required: true

  def sidebar(%{collapsible: "none"} = assigns) do
    ~H"""
    <div
      data-slot="sidebar"
      data-collapsible="none"
      data-side={@side}
      data-variant={@variant}
      class={@class}
      {@rest}
    >
      <div data-slot="sidebar-inner">
        <div :if={@header != []} data-slot="sidebar-header">{render_slot(@header)}</div>
        <div data-slot="sidebar-content">{render_slot(@inner_block)}</div>
        <div :if={@footer != []} data-slot="sidebar-footer">{render_slot(@footer)}</div>
      </div>
    </div>
    """
  end

  def sidebar(assigns) do
    ~H"""
    <div
      data-slot="sidebar"
      data-side={@side}
      data-variant={@variant}
      data-collapsible={@collapsible}
      class={@class}
      {@rest}
    >
      <div data-slot="sidebar-gap" />
      <div data-slot="sidebar-container">
        <div data-slot="sidebar-inner">
          <div :if={@header != []} data-slot="sidebar-header">{render_slot(@header)}</div>
          <div data-slot="sidebar-content">{render_slot(@inner_block)}</div>
          <div :if={@footer != []} data-slot="sidebar-footer">{render_slot(@footer)}</div>
        </div>
      </div>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  def sidebar_rail(assigns) do
    ~H"""
    <button
      type="button"
      tabindex="-1"
      data-slot="sidebar-rail"
      data-sidebar-toggle
      aria-label="Toggle sidebar"
      title="Toggle sidebar"
      class={@class}
      {@rest}
    />
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def sidebar_inset(assigns) do
    ~H"""
    <main data-slot="sidebar-inset" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </main>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  def sidebar_separator(assigns) do
    ~H"""
    <div data-slot="sidebar-separator" role="none" class={@class} {@rest} />
    """
  end

  attr :id, :any, default: nil
  attr :class, :any, default: nil
  attr :type, :string, default: "text"
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :rest, :global, include: ~w(autocomplete placeholder readonly required)

  def sidebar_input(assigns) do
    ~H"""
    <input
      id={@id}
      type={@type}
      name={@name}
      value={@value}
      data-slot="sidebar-input"
      class={@class}
      {@rest}
    />
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :label do
    attr :class, :any
  end

  slot :action do
    attr :class, :any
  end

  slot :inner_block, required: true

  def sidebar_group(assigns) do
    ~H"""
    <div data-slot="sidebar-group" class={@class} {@rest}>
      <div :for={l <- @label} data-slot="sidebar-group-label" class={l[:class]}>
        {render_slot(l)}
      </div>
      <div :for={a <- @action} data-slot="sidebar-group-action" class={a[:class]}>
        {render_slot(a)}
      </div>
      <div data-slot="sidebar-group-content">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def sidebar_menu(assigns) do
    ~H"""
    <ul data-slot="sidebar-menu" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </ul>
    """
  end

  attr :class, :any, default: nil
  attr :active, :boolean, default: false
  attr :variant, :string, values: ~w(default outline), default: "default"
  attr :size, :string, values: ~w(sm default lg), default: "default"
  attr :tooltip, :string, default: nil
  attr :collapsible, :boolean, default: false
  attr :default_open, :boolean, default: false
  attr :rest, :global, include: ~w(href navigate patch method download replace target)

  slot :icon do
    attr :class, :any
  end

  slot :action do
    attr :class, :any
    attr :show_on_hover, :boolean
  end

  slot :badge do
    attr :class, :any
  end

  slot :sub
  slot :inner_block, required: true

  def sidebar_menu_item(%{collapsible: true} = assigns) do
    ~H"""
    <li data-slot="sidebar-menu-item" class={@class}>
      <details data-slot="sidebar-menu-collapsible" open={@default_open}>
        <summary
          data-slot="sidebar-menu-button"
          data-active={@active || nil}
          data-variant={@variant}
          data-size={@size}
          aria-label={@tooltip}
        >
          <span :for={i <- @icon} data-slot="sidebar-menu-icon" class={i[:class]}>
            {render_slot(i)}
          </span>
          <span data-slot="sidebar-menu-label">{render_slot(@inner_block)}</span>
          <Lucideicons.chevron_right data-slot="sidebar-menu-chevron" />
        </summary>
        <ul :if={@sub != []} data-slot="sidebar-menu-sub">
          {render_slot(@sub)}
        </ul>
      </details>

      <span :if={@tooltip} data-slot="sidebar-menu-tooltip" role="tooltip">
        {@tooltip}
      </span>
    </li>
    """
  end

  def sidebar_menu_item(assigns) do
    ~H"""
    <li data-slot="sidebar-menu-item" class={@class}>
      <.menu_button
        active={@active}
        variant={@variant}
        size={@size}
        icon={@icon}
        tooltip={@tooltip}
        rest={@rest}
      >
        {render_slot(@inner_block)}
      </.menu_button>

      <span :if={@tooltip} data-slot="sidebar-menu-tooltip" role="tooltip">
        {@tooltip}
      </span>

      <div
        :for={a <- @action}
        data-slot="sidebar-menu-action"
        data-show-on-hover={a[:show_on_hover] && "true"}
        class={a[:class]}
      >
        {render_slot(a)}
      </div>

      <div :for={b <- @badge} data-slot="sidebar-menu-badge" class={b[:class]}>
        {render_slot(b)}
      </div>

      <ul :if={@sub != []} data-slot="sidebar-menu-sub">
        {render_slot(@sub)}
      </ul>
    </li>
    """
  end

  attr :active, :boolean, required: true
  attr :variant, :string, required: true
  attr :size, :string, required: true
  attr :tooltip, :string, default: nil
  attr :icon, :any, required: true
  attr :rest, :map, required: true
  slot :inner_block, required: true

  defp menu_button(%{rest: rest} = assigns)
       when is_map_key(rest, :href) or
              is_map_key(rest, :navigate) or
              is_map_key(rest, :patch) do
    ~H"""
    <.link
      data-slot="sidebar-menu-button"
      data-active={@active || nil}
      data-variant={@variant}
      data-size={@size}
      aria-current={@active && "page"}
      aria-label={@tooltip}
      {@rest}
    >
      <span :for={i <- @icon} data-slot="sidebar-menu-icon" class={i[:class]}>
        {render_slot(i)}
      </span>
      <span data-slot="sidebar-menu-label">{render_slot(@inner_block)}</span>
    </.link>
    """
  end

  defp menu_button(assigns) do
    ~H"""
    <button
      type="button"
      data-slot="sidebar-menu-button"
      data-active={@active || nil}
      data-variant={@variant}
      data-size={@size}
      aria-pressed={@active && "true"}
      aria-label={@tooltip}
      {@rest}
    >
      <span :for={i <- @icon} data-slot="sidebar-menu-icon" class={i[:class]}>
        {render_slot(i)}
      </span>
      <span data-slot="sidebar-menu-label">{render_slot(@inner_block)}</span>
    </button>
    """
  end

  attr :class, :any, default: nil
  attr :active, :boolean, default: false
  attr :size, :string, values: ~w(sm md), default: "md"
  attr :rest, :global, include: ~w(href navigate patch method download replace target)

  slot :inner_block, required: true

  def sidebar_menu_sub_item(assigns) do
    ~H"""
    <li data-slot="sidebar-menu-sub-item">
      <.sub_button active={@active} size={@size} class={@class} rest={@rest}>
        {render_slot(@inner_block)}
      </.sub_button>
    </li>
    """
  end

  attr :class, :any, required: true
  attr :active, :boolean, required: true
  attr :size, :string, required: true
  attr :rest, :map, required: true
  slot :inner_block, required: true

  defp sub_button(%{rest: rest} = assigns)
       when is_map_key(rest, :href) or
              is_map_key(rest, :navigate) or
              is_map_key(rest, :patch) do
    ~H"""
    <.link
      data-slot="sidebar-menu-sub-button"
      data-active={@active || nil}
      data-size={@size}
      aria-current={@active && "page"}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp sub_button(assigns) do
    ~H"""
    <button
      type="button"
      data-slot="sidebar-menu-sub-button"
      data-active={@active || nil}
      data-size={@size}
      aria-pressed={@active && "true"}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :class, :any, default: nil
  attr :with_icon, :boolean, default: false
  attr :rest, :global

  def sidebar_menu_skeleton(assigns) do
    width = "#{Enum.random(50..89)}%"
    assigns = assign(assigns, :width, width)

    ~H"""
    <div data-slot="sidebar-menu-skeleton" class={@class} {@rest}>
      <.skeleton :if={@with_icon} data-slot="sidebar-menu-skeleton-icon" class="size-4 rounded-md" />
      <.skeleton
        data-slot="sidebar-menu-skeleton-text"
        class="h-4 max-w-(--skeleton-width) flex-1"
        style={"--skeleton-width: #{@width}"}
      />
    </div>
    """
  end
end
