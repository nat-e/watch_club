defmodule Shadcn.Components.Alert do
  @moduledoc """
  Inline alert/callout for surfacing notices, warnings, or errors in-page.

      <.alert variant="destructive">
        <:icon><Lucideicons.triangle_alert /></:icon>
        <:title>Heads up!</:title>
        Something went wrong.
      </.alert>

  Ported from Shadcn on 2026-04-27
  Commit: a7d77e0cf78d338f213bed172f68261bb6c053e8
  Source: https://github.com/shadcn-ui/ui/blob/a7d77e0cf78d338f213bed172f68261bb6c053e8/apps/v4/styles/radix-vega/ui/alert.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/alert
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(default secondary destructive), default: "default"
  attr :rest, :global

  slot :icon

  slot :title do
    attr :class, :any
  end

  slot :action do
    attr :class, :any
  end

  slot :inner_block, required: true

  def alert(assigns) do
    ~H"""
    <div
      data-slot="alert"
      data-variant={@variant}
      role="alert"
      class={["group/alert", @class]}
      {@rest}
    >
      {render_slot(@icon)}
      <div
        :for={t <- @title}
        data-slot="alert-title"
        class={t[:class]}
      >
        {render_slot(t)}
      </div>
      <div data-slot="alert-description">
        {render_slot(@inner_block)}
      </div>
      <div :for={a <- @action} data-slot="alert-action" class={a[:class]}>
        {render_slot(a)}
      </div>
    </div>
    """
  end
end
