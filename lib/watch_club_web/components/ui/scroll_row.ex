defmodule WatchClubWeb.Components.UI.ScrollRow do
  @moduledoc """
  A row of items that scrolls sideways, without a scrollbar.

  On devices with a mouse, arrows show on hover. The hook hides each arrow at its end of the row
  and scrolls by most of the visible width. Keyboard users scroll by focusing the items, which the
  hook brings fully into view.
  """

  use Phoenix.Component

  import WatchClubWeb.Components.UI.Button

  attr :id, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  # The track runs into the page gutter, so items scroll to the screen edge, and has vertical
  # padding, so the items' focus outlines aren't clipped. Each edge fades while there's more to
  # scroll that way, because on wide screens the track stops before the screen edge.
  def scroll_row(assigns) do
    ~H"""
    <div id={@id} phx-hook=".ScrollRow" data-at-start class={["group/row relative", @class]}>
      <div
        data-scroll-track
        class="-mx-page -my-related flex snap-x snap-mandatory scroll-px-page gap-group overflow-x-auto px-page py-related [--fade-left:4rem] [--fade-right:4rem] [mask-image:linear-gradient(to_right,transparent,black_var(--fade-left),black_calc(100%_-_var(--fade-right)),transparent)] [scrollbar-width:none] group-data-at-start/row:[--fade-left:0px] group-data-at-end/row:[--fade-right:0px] [&::-webkit-scrollbar]:hidden"
      >
        {render_slot(@inner_block)}
      </div>
      <div
        :for={
          {direction, edge} <- [
            {"prev", "left-0 group-data-at-start/row:invisible"},
            {"next", "right-0 group-data-at-end/row:invisible"}
          ]
        }
        class={[
          "pointer-events-none absolute inset-y-0 z-10 hidden items-center opacity-0 transition-opacity duration-150 group-hover/row:pointer-events-auto group-hover/row:opacity-100 [@media(hover:hover)]:flex",
          edge
        ]}
      >
        <.button
          id={"#{@id}-#{direction}"}
          variant="secondary"
          size="icon"
          data-scroll={direction}
          tabindex="-1"
          aria-hidden="true"
          class="rounded-full! shadow-overlay"
        >
          <Lucideicons.chevron_left :if={direction == "prev"} />
          <Lucideicons.chevron_right :if={direction == "next"} />
        </.button>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".ScrollRow">
        export default {
          mounted() {
            this.track = this.el.querySelector("[data-scroll-track]")
            this.update = () => {
              const { scrollLeft, scrollWidth, clientWidth } = this.track
              this.el.toggleAttribute("data-at-start", scrollLeft <= 1)
              this.el.toggleAttribute("data-at-end", scrollLeft + clientWidth >= scrollWidth - 1)
            }
            this.track.addEventListener("scroll", this.update, { passive: true })
            this.resizeObserver = new ResizeObserver(this.update)
            this.resizeObserver.observe(this.track)
            this.behavior = () =>
              window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth"
            this.el.addEventListener("click", (event) => {
              const button = event.target.closest("[data-scroll]")
              if (!button) return

              const direction = button.dataset.scroll === "next" ? 1 : -1
              this.track.scrollBy({ left: direction * this.track.clientWidth * 0.8, behavior: this.behavior() })
            })
            this.track.addEventListener("focusin", (event) => {
              const item = [...this.track.children].find((child) => child.contains(event.target))
              item?.scrollIntoView({ inline: "nearest", block: "nearest", behavior: this.behavior() })
            })
            this.update()
          },
          updated() { this.update() },
          destroyed() { this.resizeObserver.disconnect() },
        }
      </script>
    </div>
    """
  end
end
