defmodule Shadcn.Components.Dialog do
  @moduledoc """
  Content layout for a modal: header (title + description), body, and
  footer. Renders no chrome of its own — wrap it in `<.modal>` for the
  overlay, backdrop, focus trap, and ESC-to-close behavior.

      <.modal id="invite-modal" open={@open}>
        <.dialog>
          <:title>Invite a teammate</:title>
          <:description>Send an email invitation.</:description>

          <.input name="email" placeholder="you@example.com" />

          <:footer>
            <.button data-modal-close>Cancel</.button>
            <.button>Send invite</.button>
          </:footer>
        </.dialog>
      </.modal>

  Closing is the modal's responsibility: any descendant with
  `data-modal-close` will dismiss the surrounding `<.modal>`. Because
  Dialog is just layout, it can also be used outside a modal (e.g.
  inline panels) when you want the same header/body/footer rhythm.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/dialog.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/dialog
  Radix doc: https://www.radix-ui.com/primitives/docs/components/dialog
  """
  use Phoenix.Component

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  slot :title do
    attr :class, :any
  end

  slot :description do
    attr :class, :any
  end

  slot :footer do
    attr :class, :any
  end

  slot :inner_block

  def dialog(assigns) do
    ~H"""
    <div data-slot="dialog" class={["group/dialog", @class]}>
      <div data-slot="dialog-header">
        <h2 :for={t <- @title} data-slot="dialog-title" class={t[:class]}>
          {render_slot(t)}
        </h2>
        <p
          :for={d <- @description}
          id={"#{@id}-description"}
          data-slot="dialog-description"
          class={d[:class]}
        >
          {render_slot(d)}
        </p>
      </div>

      <div :if={@inner_block != []} data-slot="dialog-body">
        {render_slot(@inner_block)}
      </div>

      <div :for={f <- @footer} data-slot="dialog-footer" class={f[:class]}>
        {render_slot(f)}
      </div>
    </div>
    """
  end
end
