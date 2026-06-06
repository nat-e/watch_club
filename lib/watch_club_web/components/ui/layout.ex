defmodule WatchClubWeb.Components.UI.Layout do
  @moduledoc """
  Token-driven layout primitives.

  These primitives encode repeated spacing and surface patterns while still
  keeping layout readable in HEEX templates.
  """

  use Phoenix.Component

  import WatchClubWeb.Components.UI.LucideIcon

  attr :as, :string, values: ~w(div ul ol), default: "div", doc: "HTML tag for the stack root."

  attr :space, :string,
    values: ~w(none tight related group cluster section),
    default: "group"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def stack(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@as}
      class={[
        "flex flex-col",
        @space == "tight" && "gap-tight",
        @space == "related" && "gap-related",
        @space == "group" && "gap-group",
        @space == "cluster" && "gap-cluster",
        @space == "section" && "gap-section",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end

  attr :as, :string, values: ~w(div ul ol), default: "div", doc: "HTML tag for the inline root."

  attr :space, :string,
    values: ~w(none tight related group cluster section),
    default: "related"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def inline(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@as}
      class={[
        "flex items-center",
        @space == "tight" && "gap-tight",
        @space == "related" && "gap-related",
        @space == "group" && "gap-group",
        @space == "cluster" && "gap-cluster",
        @space == "section" && "gap-section",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end

  attr :as, :string, values: ~w(div ul ol), default: "div", doc: "HTML tag for the cluster root."

  attr :space, :string,
    values: ~w(none tight related group cluster section),
    default: "related"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def cluster(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@as}
      class={[
        "flex flex-wrap items-center",
        @space == "tight" && "gap-tight",
        @space == "related" && "gap-related",
        @space == "group" && "gap-group",
        @space == "cluster" && "gap-cluster",
        @space == "section" && "gap-section",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end

  attr :width, :string,
    values: ~w(full readable panel page),
    default: "page"

  attr :space, :string,
    values: ~w(none tight related group cluster section),
    default: "cluster"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def page(assigns) do
    ~H"""
    <div
      data-slot="page"
      class={[
        "mx-auto grid w-full px-page py-page-y",
        @width == "readable" && "max-w-readable",
        @width == "panel" && "max-w-panel",
        @width == "page" && "max-w-layout-page",
        @space == "tight" && "gap-tight",
        @space == "related" && "gap-related",
        @space == "group" && "gap-group",
        @space == "cluster" && "gap-cluster",
        @space == "section" && "gap-section",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :icon, :any, default: nil

  attr :space, :string,
    values: ~w(none tight related group cluster section),
    default: "cluster"

  attr :padding, :string,
    values: ~w(none tight related group cluster),
    default: "cluster"

  attr :surface, :string,
    values: ~w(default raised inset overlay transparent),
    default: "default"

  attr :shadow, :boolean, default: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :action
  slot :inner_block, required: true

  def section(assigns) do
    assigns =
      assign(
        assigns,
        :header?,
        !!(assigns.title || assigns.description || assigns.icon || assigns.action != [])
      )

    ~H"""
    <.card
      as="section"
      data_slot="section"
      padding={@padding}
      surface={@surface}
      shadow={@shadow}
      class={[
        "grid",
        @space == "tight" && "gap-tight",
        @space == "related" && "gap-related",
        @space == "group" && "gap-group",
        @space == "cluster" && "gap-cluster",
        @space == "section" && "gap-section",
        @class
      ]}
      {@rest}
    >
      <div
        :if={@header?}
        class="flex flex-col items-start gap-group sm:flex-row sm:items-start sm:justify-between"
      >
        <div class={[
          "flex min-w-0 gap-tight",
          @description && "items-start",
          !@description && "items-center"
        ]}>
          <span
            :if={@icon}
            class="inline-flex size-control-md shrink-0 items-center justify-center text-accent"
          >
            <.lucide_icon name={@icon} class="size-icon" />
          </span>
          <div class="flex flex-col min-w-0 gap-tight">
            <h2 :if={@title} class="text-xl font-heading font-semibold tracking-tight text-text">
              {@title}
            </h2>
            <p :if={@description} class="max-w-readable text-sm leading-6 text-text-muted">
              {@description}
            </p>
          </div>
        </div>
        <div :if={@action != []} class="shrink-0">
          {render_slot(@action)}
        </div>
      </div>

      {render_slot(@inner_block)}
    </.card>
    """
  end

  attr :padding, :string,
    values: ~w(none tight related group cluster),
    default: "group"

  attr :surface, :string,
    values: ~w(default raised inset overlay transparent),
    default: "default"

  attr :shadow, :boolean, default: true

  attr :as, :string,
    values: ~w(section article div),
    default: "section",
    doc: "HTML tag used for the card root."

  attr :data_slot, :string, default: "card"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@as}
      data-slot={@data_slot}
      class={[
        "rounded-card border text-text",
        @surface == "default" && "border-border-subtle bg-surface",
        @surface == "raised" && "border-border bg-surface-raised",
        @surface == "inset" && "border-border-subtle bg-surface-inset",
        @surface == "overlay" && "border-border bg-surface-overlay",
        @surface == "transparent" && "border-border-subtle bg-transparent",
        @padding == "tight" && "p-tight",
        @padding == "related" && "p-related",
        @padding == "group" && "p-group",
        @padding == "cluster" && "p-cluster",
        @shadow && "shadow-card",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end
end
