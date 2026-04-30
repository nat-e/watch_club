defmodule Shadcn.Components.Drawer do
  @moduledoc """
  Edge-anchored modal optimized for mobile / touch interfaces.

      <.drawer id="checkout">
        <:trigger><.button>Checkout</.button></:trigger>
        <:title>Confirm purchase</:title>
        <:description>Review the order before paying.</:description>

        <p>Cart contents...</p>

        <:footer>
          <.button data-drawer-close variant="outline">Cancel</.button>
          <.button>Pay now</.button>
        </:footer>
      </.drawer>

  Same backbone as `<.sheet>` (native `<dialog>` + JS hook). The `direction`
  attribute drives which edge the drawer slides in from. Touch
  drag-to-dismiss (vaul's signature interaction) is not implemented.

  Ported from Shadcn on 2026-04-29
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/drawer.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/drawer
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :direction, :string, values: ~w(top right bottom left), default: "bottom"
  attr :rest, :global

  slot :trigger

  slot :title, required: true do
    attr :class, :any
  end

  slot :description do
    attr :class, :any
  end

  slot :footer do
    attr :class, :any
  end

  slot :inner_block, required: true

  def drawer(assigns) do
    ~H"""
    <div id={@id} data-slot="drawer" phx-hook="DrawerHook" class={["group/drawer", @class]} {@rest}>
      <div :if={@trigger != []} data-slot="drawer-trigger">
        {render_slot(@trigger)}
      </div>
      <dialog
        id={"#{@id}-content"}
        data-slot="drawer-content"
        data-direction={@direction}
        aria-labelledby={"#{@id}-title"}
      >
        <div :if={@direction == "bottom"} data-slot="drawer-handle" aria-hidden="true" />
        <div data-slot="drawer-header">
          <h2 :for={t <- @title} id={"#{@id}-title"} data-slot="drawer-title" class={t[:class]}>
            {render_slot(t)}
          </h2>
          <p :for={d <- @description} data-slot="drawer-description" class={d[:class]}>
            {render_slot(d)}
          </p>
        </div>
        <div data-slot="drawer-body">
          {render_slot(@inner_block)}
        </div>
        <div :for={f <- @footer} data-slot="drawer-footer" class={f[:class]}>
          {render_slot(f)}
        </div>
      </dialog>
    </div>
    """
  end
end
