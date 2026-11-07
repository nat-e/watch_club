defmodule WatchClubWeb.Components.Prototypes.Controls do
  @moduledoc """
  The controls of a prototype page, which renders like the real app around them: a flask button
  in the top bar's right corner, and the panel it toggles under it, closed when the page opens.
  The panel holds the experiment's name, a link to every prototype, then its variation pickers
  and sample data.
  """
  use WatchClubWeb, :component

  attr :id, :string, default: "prototype-controls"
  attr :title, :string, required: true, doc: "the experiment's name"
  slot :inner_block, required: true, doc: "variation pickers and sample data"

  def prototype_controls(assigns) do
    ~H"""
    <div id={@id} class="group" data-closed>
      <div class="fixed top-0 right-0 z-30 flex h-(--wc-size-row-lg) items-center pr-page">
        <.button
          id={"#{@id}-toggle"}
          variant="ghost"
          size="icon"
          class="text-text! max-md:rounded-full! pointer-coarse:size-touch-target! group-data-closed:text-text-muted!"
          aria-label="Prototype controls"
          aria-controls={"#{@id}-panel"}
          title={@title}
          phx-click={JS.toggle_attribute({"data-closed", ""}, to: "##{@id}")}
        ><Lucideicons.flask_conical /></.button>
      </div>
      <section
        id={"#{@id}-panel"}
        aria-labelledby={"#{@id}-title"}
        class="fixed inset-x-group top-[calc(var(--wc-size-row-lg)+var(--spacing-tight))] z-40 flex max-h-[60svh] flex-col overflow-hidden rounded-card border border-border bg-surface-raised shadow-overlay group-data-closed:hidden md:left-auto md:w-sm"
      >
        <header class="flex items-center gap-related border-b border-border-subtle py-related pr-related pl-group">
          <h2 id={"#{@id}-title"} class="min-w-0 flex-1 truncate text-sm font-semibold">{@title}</h2>
          <.button id={"#{@id}-all"} variant="ghost" size="sm" navigate="/dev/prototypes">
            All prototypes
          </.button>
        </header>
        <div class="flex min-h-0 flex-col gap-group overflow-y-auto p-group">
          {render_slot(@inner_block)}
        </div>
      </section>
    </div>
    """
  end
end
