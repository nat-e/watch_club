defmodule Shadcn.Components.Sheet do
  @moduledoc """
  Side-anchored modal that slides in from an edge of the viewport.

      <.sheet id="filters" side="right">
        <:trigger><.button variant="outline">Filters</.button></:trigger>
        <:title>Filter watches</:title>
        <:description>Refine your collection.</:description>

        <p>Filter controls go here.</p>

        <:footer>
          <.button data-sheet-close variant="outline">Cancel</.button>
          <.button>Apply</.button>
        </:footer>
      </.sheet>

  Same backbone as `<.dialog>` (native `<dialog>` + JS hook). The `side`
  attribute drives the slide direction.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/sheet.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/sheet
  Radix doc: https://www.radix-ui.com/primitives/docs/components/dialog
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :side, :string, values: ~w(top right bottom left), default: "right"
  attr :show_close, :boolean, default: true
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

  def sheet(assigns) do
    ~H"""
    <div id={@id} data-slot="sheet" phx-hook="SheetHook" class={["group/sheet", @class]} {@rest}>
      <div :if={@trigger != []} data-slot="sheet-trigger">
        {render_slot(@trigger)}
      </div>
      <dialog
        id={"#{@id}-content"}
        data-slot="sheet-content"
        data-side={@side}
        aria-labelledby={"#{@id}-title"}
      >
        <div data-slot="sheet-header">
          <h2 :for={t <- @title} id={"#{@id}-title"} data-slot="sheet-title" class={t[:class]}>
            {render_slot(t)}
          </h2>
          <p :for={d <- @description} data-slot="sheet-description" class={d[:class]}>
            {render_slot(d)}
          </p>
        </div>

        <div data-slot="sheet-body">
          {render_slot(@inner_block)}
        </div>

        <div :for={f <- @footer} data-slot="sheet-footer" class={f[:class]}>
          {render_slot(f)}
        </div>

        <button
          :if={@show_close}
          type="button"
          data-sheet-close
          data-slot="sheet-close-icon"
          aria-label="Close"
        >
          <Lucideicons.x />
        </button>
      </dialog>
    </div>
    """
  end
end
