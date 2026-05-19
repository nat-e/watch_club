defmodule WatchClubWeb.Components.UI.InfiniteScroll do
  @moduledoc """
  Infinite scrolling trigger primitive.

  Renders a small loading sentinel that pushes an event when it enters the viewport.
  The hook re-checks after each successful push so pages keep loading until the
  sentinel leaves the viewport or the parent stops rendering it.
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
            this.observer = new IntersectionObserver((entries) => {
              if (entries.some((entry) => entry.isIntersecting)) this.loadMore()
            })
            this.observer.observe(this.el)
            this.check()
          },
          updated() { this.check() },
          destroyed() { this.observer?.disconnect() },
          check() {
            window.requestAnimationFrame(() => {
              if (!this.el.isConnected) return

              const rect = this.el.getBoundingClientRect()
              const viewportHeight = window.innerHeight || document.documentElement.clientHeight
              if (rect.top <= viewportHeight && rect.bottom >= 0) this.loadMore()
            })
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
