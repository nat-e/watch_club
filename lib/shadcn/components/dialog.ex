defmodule Shadcn.Components.Dialog do
  @moduledoc """
  Modal dialog overlaid on the page.

      <.dialog id="invite-dialog">
        <:trigger><.button variant="outline">Invite</.button></:trigger>
        <:title>Invite a teammate</:title>
        <:description>Send an email invitation.</:description>

        <.input name="email" placeholder="you@example.com" />

        <:footer>
          <.button data-dialog-close>Cancel</.button>
          <.button>Send invite</.button>
        </:footer>
      </.dialog>

  Built on the native `<dialog>` element, so focus trap and ESC-to-close
  come from the browser. The `DialogHook` toggles `showModal()` / `close()`
  on trigger click and on any descendant with `data-dialog-close`.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/dialog.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/dialog
  Radix doc: https://www.radix-ui.com/primitives/docs/components/dialog
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :show_close, :boolean, default: true
  attr :open, :boolean, default: false
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

  slot :inner_block

  def dialog(assigns) do
    ~H"""
    <div id={@id} data-slot="dialog" phx-hook="DialogHook" class={["group/dialog", @class]} {@rest}>
      <div :if={@trigger != []} data-slot="dialog-trigger">
        {render_slot(@trigger)}
      </div>
      <dialog
        id={"#{@id}-content"}
        data-slot="dialog-content"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={if @description != [], do: "#{@id}-description", else: nil}
        open={@open}
      >
        <div data-slot="dialog-header">
          <h2 :for={t <- @title} id={"#{@id}-title"} data-slot="dialog-title" class={t[:class]}>
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

        <button
          :if={@show_close}
          type="button"
          data-dialog-close
          data-slot="dialog-close-icon"
          aria-label="Close"
        >
          <Lucideicons.x />
        </button>
      </dialog>
    </div>
    """
  end
end
