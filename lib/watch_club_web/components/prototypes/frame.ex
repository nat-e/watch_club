defmodule WatchClubWeb.Components.Prototypes.Frame do
  @moduledoc """
  The frame of the developer tool pages, such as the list of prototypes: navigation, title
  and controls. Prototype pages use the app layout and `Prototypes.Controls` instead.
  """
  use WatchClubWeb, :component

  attr :id, :string, default: "prototype-frame"
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :level, :string, default: nil
  attr :back, :string, default: "/dev/prototypes"
  attr :back_label, :string, default: "All prototypes"
  attr :flash, :map, default: %{}
  slot :controls
  slot :action
  slot :inner_block, required: true

  def prototype_frame(assigns) do
    ~H"""
    <div id={@id} class="@container min-h-svh bg-canvas text-text">
      <.flash id={"#{@id}-flash"} flash={@flash} />
      <.page width="page" space="section" class="flex! flex-col">
        <header class="flex min-w-0 flex-col gap-cluster">
          <nav aria-label="Development" class="flex items-center justify-between gap-group text-sm">
            <.link
              navigate={@back}
              class="inline-flex min-h-touch-target items-center gap-tight rounded-control text-text-muted hover:text-text focus-visible:outline-2 focus-visible:outline-focus focus-visible:outline-offset-2"
            >
              <Lucideicons.arrow_left class="size-icon-sm" />
              {@back_label}
            </.link>
            {render_slot(@action)}
          </nav>
          <div class="flex flex-col gap-related">
            <.badge :if={@level} variant="muted">{String.capitalize(@level)}</.badge>
            <h1 class="font-heading text-2xl font-semibold tracking-tight @lg:text-3xl">{@title}</h1>
            <p :if={@description} class="max-w-readable text-text-muted">{@description}</p>
          </div>
          <div :if={@controls != []} class="flex min-w-0 flex-col gap-group">
            {render_slot(@controls)}
          </div>
        </header>
        <main class="min-w-0">{render_slot(@inner_block)}</main>
      </.page>
    </div>
    """
  end
end
