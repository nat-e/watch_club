defmodule WatchClubWeb.Components.UI.Layout do
  @moduledoc """
  Token-driven layout primitives.

  These primitives encode repeated spacing and surface patterns while still
  keeping layout readable in HEEX templates.
  """

  use Phoenix.Component

  attr :space, :string,
    values: ~w(none tight related group cluster section),
    default: "group"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def stack(assigns) do
    ~H"""
    <div
      data-slot="stack"
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
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :space, :string,
    values: ~w(none tight related group cluster section),
    default: "related"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def inline(assigns) do
    ~H"""
    <div
      data-slot="inline"
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
    </div>
    """
  end

  attr :space, :string,
    values: ~w(none tight related group cluster section),
    default: "related"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def cluster(assigns) do
    ~H"""
    <div
      data-slot="cluster"
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
    </div>
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

  attr :space, :string,
    values: ~w(none tight related group cluster section),
    default: "cluster"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <section
      data-slot="section"
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
      {render_slot(@inner_block)}
    </section>
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
