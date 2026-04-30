defmodule Shadcn.Components.AlertDialog do
  @moduledoc """
  Modal confirmation dialog — interrupts the user with an important
  message and forces a yes/no decision.

      <.alert_dialog id="confirm-delete">
        <:trigger><.button variant="destructive">Delete</.button></:trigger>
        <:title>Are you sure?</:title>
        <:description>This permanently removes the watch.</:description>
        <:cancel>Cancel</:cancel>
        <:action variant="destructive">Delete</:action>
      </.alert_dialog>

  Pass `size="sm"` for a compact layout (footer becomes a 2-col grid).
  Add a `<:media>` slot to surface a centered icon block above the
  title; on default size at `sm+` widths, the media moves to the left
  and spans the title + description rows.

  Differences from `<.dialog>`: the alert dialog has no close icon, no
  click-outside-to-close, and the trigger pattern is forced to a
  Cancel/Action button pair. Built on the same native `<dialog>`.

  Ported from Shadcn on 2026-04-28
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/alert-dialog.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/alert-dialog
  Radix doc: https://www.radix-ui.com/primitives/docs/components/alert-dialog
  """
  use Phoenix.Component

  import Shadcn.Components.Button

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :size, :string, values: ~w(default sm), default: "default"
  attr :rest, :global

  slot :trigger

  slot :media do
    attr :class, :any
  end

  slot :title, required: true do
    attr :class, :any
  end

  slot :description do
    attr :class, :any
  end

  slot :cancel do
    attr :variant, :string
    attr :class, :any
  end

  slot :action do
    attr :variant, :string
    attr :class, :any
  end

  slot :inner_block

  def alert_dialog(assigns) do
    ~H"""
    <div
      id={@id}
      data-slot="alert-dialog"
      phx-hook="AlertDialogHook"
      class={["group/alert-dialog", @class]}
      {@rest}
    >
      <div :if={@trigger != []} data-slot="alert-dialog-trigger">
        {render_slot(@trigger)}
      </div>
      <dialog
        id={"#{@id}-content"}
        data-slot="alert-dialog-content"
        data-size={@size}
        role="alertdialog"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={if @description != [], do: "#{@id}-description", else: nil}
        class="group/alert-dialog-content"
      >
        <div data-slot="alert-dialog-header">
          <div
            :for={m <- @media}
            data-slot="alert-dialog-media"
            class={m[:class]}
          >
            {render_slot(m)}
          </div>
          <h2
            :for={t <- @title}
            id={"#{@id}-title"}
            data-slot="alert-dialog-title"
            class={t[:class]}
          >
            {render_slot(t)}
          </h2>
          <p
            :for={d <- @description}
            id={"#{@id}-description"}
            data-slot="alert-dialog-description"
            class={d[:class]}
          >
            {render_slot(d)}
          </p>
        </div>

        <div :if={@inner_block != []} data-slot="alert-dialog-body">
          {render_slot(@inner_block)}
        </div>

        <div data-slot="alert-dialog-footer">
          <.button
            :for={c <- @cancel}
            variant={c[:variant] || "outline"}
            data-alert-dialog-cancel
            class={c[:class]}
          >
            {render_slot(c)}
          </.button>
          <.button
            :for={a <- @action}
            variant={a[:variant] || "default"}
            data-alert-dialog-action
            class={a[:class]}
          >
            {render_slot(a)}
          </.button>
        </div>
      </dialog>
    </div>
    """
  end
end
