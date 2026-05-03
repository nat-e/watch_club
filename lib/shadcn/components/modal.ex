defmodule Shadcn.Components.Modal do
  @moduledoc """
  Overlay chrome built on the native `<dialog>` element. Owns the
  backdrop, focus trap, ESC-to-close, click-outside-to-close, and the
  optional top-right close button. Content layout is delegated — wrap a
  `<.dialog>` (or anything else) inside.

      <.modal id="invite-modal" open={@open} on_close={JS.patch(~p"/clubs")}>
        <.dialog>
          <:title>Invite a teammate</:title>
          ...
        </.dialog>
      </.modal>

  ## Closing

  Any descendant with `data-modal-close` will close the modal. The
  native `close` event also fires on ESC and backdrop click; pass
  `on_close` to run a `Phoenix.LiveView.JS` command on every dismissal
  (e.g. patch the URL back to a canonical state for URL-driven modals).
  """
  alias Phoenix.LiveView.JS
  use Phoenix.Component

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :show_close, :boolean, default: true
  attr :open, :boolean, default: false
  attr :rest, :global
  attr :on_close, JS, default: nil

  slot :inner_block, required: true

  def modal(assigns) do
    assigns = assigns |> assign(:id, assigns.id || "modal-#{System.unique_integer([:positive])}")

    ~H"""
    <dialog
      id={@id}
      data-slot="modal"
      open={@open}
      data-on-close={@on_close}
      class={["group/modal", @class]}
      phx-hook="ModalHook"
    >
      {render_slot(@inner_block)}

      <button
        :if={@show_close}
        type="button"
        data-modal-close
        data-slot="modal-close"
        aria-label="Close"
      >
        <Lucideicons.x />
      </button>
    </dialog>
    """
  end
end
