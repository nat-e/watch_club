defmodule Shadcn.Components.Card do
  @moduledoc """
  Container that groups related content with optional title, description,
  header action, image, and footer.

      <.card>
        <:title>Account</:title>
        <:description>Manage your account settings.</:description>
        <p>Update your profile, password, and preferences here.</p>
      </.card>

      <.card size="sm">
        <:title>Notifications</:title>
        <:description>You have 3 unread messages.</:description>
        <:action>
          <.button variant="ghost" size="sm">Edit</.button>
        </:action>
        <p>Mark them all as read or open your inbox.</p>
        <:footer>
          <.button>Mark all as read</.button>
        </:footer>
      </.card>

  Ported from Shadcn on 2026-04-28
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/card.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/card
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :size, :string, values: ~w(sm default), default: "default"
  attr :rest, :global

  slot :image

  slot :title do
    attr :class, :any
  end

  slot :description do
    attr :class, :any
  end

  slot :action do
    attr :class, :any
  end

  slot :inner_block

  slot :footer do
    attr :class, :any
  end

  def card(assigns) do
    has_header? = assigns.title != [] or assigns.description != [] or assigns.action != []
    assigns = assign(assigns, :has_header?, has_header?)

    ~H"""
    <div data-slot="card" data-size={@size} class={["group/card", @class]} {@rest}>
      {render_slot(@image)}
      <div :if={@has_header?} data-slot="card-header">
        <div :for={t <- @title} data-slot="card-title" class={t[:class]}>
          {render_slot(t)}
        </div>
        <div :for={d <- @description} data-slot="card-description" class={d[:class]}>
          {render_slot(d)}
        </div>
        <div :for={a <- @action} data-slot="card-action" class={a[:class]}>
          {render_slot(a)}
        </div>
      </div>
      <div data-slot="card-content">
        {render_slot(@inner_block)}
      </div>
      <div :for={f <- @footer} data-slot="card-footer" class={f[:class]}>
        {render_slot(f)}
      </div>
    </div>
    """
  end
end
