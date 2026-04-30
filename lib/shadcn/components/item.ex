defmodule Shadcn.Components.Item do
  @moduledoc """
  List item layout — media + content + actions.

      <.item_group>
        <.item :for={user <- @users}>
          <:media variant="image"><img src={user.avatar} alt="" /></:media>
          <:title>{user.name}</:title>
          <:description>{user.email}</:description>
          <:actions>
            <.button variant="outline" size="sm">Invite</.button>
          </:actions>
        </.item>
      </.item_group>

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/item.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/item
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def item_group(assigns) do
    ~H"""
    <div role="list" data-slot="item-group" class={["group/item-group", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global

  def item_separator(assigns) do
    ~H"""
    <div
      role="separator"
      aria-orientation="horizontal"
      data-slot="item-separator"
      class={@class}
      {@rest}
    />
    """
  end

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(default outline muted), default: "default"
  attr :size, :string, values: ~w(xs sm default), default: "default"
  attr :rest, :global, include: ~w(href navigate patch role)

  slot :header do
    attr :class, :any
  end

  slot :media do
    attr :variant, :string, values: ~w(default icon image)
    attr :class, :any
  end

  slot :title do
    attr :class, :any
  end

  slot :description do
    attr :class, :any
  end

  slot :actions do
    attr :class, :any
  end

  slot :footer do
    attr :class, :any
  end

  slot :inner_block

  def item(%{rest: rest} = assigns)
      when is_map_key(rest, :href) or
             is_map_key(rest, :navigate) or
             is_map_key(rest, :patch) do
    ~H"""
    <.link
      data-slot="item"
      data-variant={@variant}
      data-size={@size}
      class={["group/item", @class]}
      {@rest}
    >
      {item_inner(assigns)}
    </.link>
    """
  end

  def item(assigns) do
    ~H"""
    <div
      role="listitem"
      data-slot="item"
      data-variant={@variant}
      data-size={@size}
      class={["group/item", @class]}
      {@rest}
    >
      {item_inner(assigns)}
    </div>
    """
  end

  defp item_inner(assigns) do
    ~H"""
    <div :for={h <- @header} data-slot="item-header" class={h[:class]}>
      {render_slot(h)}
    </div>
    <div
      :for={m <- @media}
      data-slot="item-media"
      data-variant={m[:variant] || "default"}
      class={m[:class]}
    >
      {render_slot(m)}
    </div>
    <div data-slot="item-content">
      <div :for={t <- @title} data-slot="item-title" class={t[:class]}>
        {render_slot(t)}
      </div>
      <p :for={d <- @description} data-slot="item-description" class={d[:class]}>
        {render_slot(d)}
      </p>
      {render_slot(@inner_block)}
    </div>
    <div :for={a <- @actions} data-slot="item-actions" class={a[:class]}>
      {render_slot(a)}
    </div>
    <div :for={f <- @footer} data-slot="item-footer" class={f[:class]}>
      {render_slot(f)}
    </div>
    """
  end
end
