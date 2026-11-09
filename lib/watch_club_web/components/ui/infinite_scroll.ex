defmodule WatchClubWeb.Components.UI.InfiniteScroll do
  @moduledoc """
  Infinite scrolling trigger primitive.

  Renders a small loading sentinel that pushes an event when it comes within one screen
  height below the viewport, so the next page is usually there before the user reaches the
  end of the list. The hook re-checks after each successful push so pages keep loading until
  the sentinel is more than one screen height below the viewport or the parent stops
  rendering it.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :event, :string, required: true
  attr :target, :any, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  def infinite_scroll_trigger(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook=".InfiniteScrollTrigger"
      data-event={@event}
      data-target={@target}
      aria-hidden="true"
      class={["flex w-full justify-center py-related text-text-muted", @class]}
      {@rest}
    >
      <Lucideicons.loader_circle class="size-icon-sm animate-spin" />

      <script :type={Phoenix.LiveView.ColocatedHook} name=".InfiniteScrollTrigger">
        export default {
          mounted() {
            this.loading = false
            this.observer = new IntersectionObserver(
              (entries) => {
                if (entries.some((entry) => entry.isIntersecting)) this.loadMore()
              },
              // The viewport plus one screen height below it
              { rootMargin: "0px 0px 100% 0px" }
            )
            this.observer.observe(this.el)
          },
          updated() { this.check() },
          destroyed() { this.observer?.disconnect() },
          // Observing again makes the observer report whether the sentinel is still in range
          check() {
            this.observer.unobserve(this.el)
            this.observer.observe(this.el)
          },
          loadMore() {
            if (this.loading) return

            this.loading = true
            const done = () => {
              this.loading = false
              this.check()
            }

            if (this.el.dataset.target) {
              this.pushEventTo(this.el.dataset.target, this.el.dataset.event, {}, done)
            } else {
              this.pushEvent(this.el.dataset.event, {}, done)
            }
          },
        }
      </script>
    </div>
    """
  end
end
