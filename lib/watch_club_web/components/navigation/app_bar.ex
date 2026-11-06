defmodule WatchClubWeb.Components.Navigation.AppBar do
  @moduledoc """
  The bar at the top of `WatchClubWeb.Layouts.app/1`, which owns its contract: back, the page's
  name and, on the pages that ask for it, the search field. `/` or Cmd/Ctrl+K focuses the search
  field.
  """
  use WatchClubWeb, :component

  alias WatchClubWeb.Components.Navigation.SearchFieldLive

  attr :title, :string, required: true
  attr :content_page?, :boolean, required: true
  attr :parent, :list, required: true, doc: "the `:parent` slot of `Layouts.app`"
  attr :search, :boolean, required: true
  attr :current_url, Url, required: true
  attr :current_user, User, required: true
  attr :class, :any, default: nil

  def app_bar(assigns) do
    assigns = assign(assigns, :back, back(assigns.parent, assigns.content_page?))

    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".AppBar">
      export default {
        mounted() {
          this.toggle = (name, on) => on ? this.el.setAttribute(name, "") : this.el.removeAttribute(name)
          this.onScroll = () => {
            this.toggle("data-scrolled", window.scrollY > 8)
            const title = document.querySelector("[data-page-title]")
            this.toggle("data-past-title", !!title && title.getBoundingClientRect().bottom < this.el.getBoundingClientRect().bottom)
          }
          this.onKeydown = (e) => {
            const typing = e.target.closest("input, textarea, select, [contenteditable]")
            const shortcut = (e.key === "/" && !typing) || ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k")
            const field = [...document.querySelectorAll("[data-search-field]")].find(el => el.getClientRects().length)
            if (!shortcut || !field) return
            e.preventDefault()
            field.focus()
          }
          // The back link goes back in history when there is a previous page, and follows its href otherwise
          this.el.addEventListener("click", (e) => {
            const back = e.target.closest("[data-back]")
            const newTab = e.metaKey || e.ctrlKey || e.shiftKey || e.button !== 0
            const canGoBack = window.navigation ? window.navigation.canGoBack : history.length > 1
            if (!back || newTab || !canGoBack) return
            e.preventDefault()
            e.stopPropagation()
            history.back()
          })
          window.addEventListener("scroll", this.onScroll, {passive: true})
          window.addEventListener("resize", this.onScroll)
          window.addEventListener("keydown", this.onKeydown)
          this.onScroll()
        },
        updated() { this.onScroll() },
        destroyed() {
          window.removeEventListener("scroll", this.onScroll)
          window.removeEventListener("resize", this.onScroll)
          window.removeEventListener("keydown", this.onKeydown)
        }
      }
    </script>
    <header
      id="app-bar"
      phx-hook=".AppBar"
      phx-mounted={JS.ignore_attributes(["data-scrolled", "data-past-title"])}
      class={[
        "group/bar @container/bar sticky top-0 z-20 flex h-(--wc-app-bar-height) items-center border-b pr-page transition-colors duration-200 max-md:has-[[data-open]]:z-50 md:pl-page",
        @back && "gap-tight pl-tight md:gap-group",
        !@back && "gap-group pl-page",
        @content_page? &&
          "border-transparent bg-transparent data-scrolled:border-border-subtle data-scrolled:bg-canvas",
        !@content_page? &&
          "border-transparent bg-canvas data-scrolled:border-border-subtle md:border-border-subtle",
        @class
      ]}
    >
      <.button
        :if={@back}
        id="app-bar-back"
        variant="ghost"
        size="icon"
        class="text-text! max-md:rounded-full! pointer-coarse:size-touch-target!"
        navigate={@back.navigate}
        data-back={@back.history?}
        aria-label={@back.label}
        title={@back.label}
      >
        <Lucideicons.arrow_left />
      </.button>

      <div class={["flex min-w-0 flex-1 items-center", @search && "max-md:flex-none"]}>
        <.page_name title={@title} content_page?={@content_page?} />
      </div>

      <div :if={@search} class="ml-auto shrink-0 max-md:min-w-0 max-md:flex-1">
        <.live_component
          module={SearchFieldLive}
          id="app-bar-search"
          current_url={@current_url}
          current_user={@current_user}
        />
      </div>
    </header>
    """
  end

  # A child page goes up to its parent. A Content page goes back to the previous page, or Browse
  # when the history has no previous page of the app: see the hook.
  defp back([parent], _content_page?) do
    label = dgettext("nav", "Back to %{page}", page: parent.label)
    %{navigate: parent.navigate, label: label, history?: false}
  end

  defp back([], true), do: %{navigate: ~p"/", label: dgettext("nav", "Back"), history?: true}
  defp back([], false), do: nil

  attr :title, :string, required: true
  attr :content_page?, :boolean, required: true

  # The page shows its title in its hero: the bar shows it once the hero's title scrolls away.
  defp page_name(%{content_page?: true} = assigns) do
    ~H"""
    <p
      aria-hidden="true"
      class="truncate text-base font-semibold opacity-0 transition-opacity duration-200 group-data-past-title/bar:opacity-100"
    >
      {@title}
    </p>
    """
  end

  defp page_name(assigns) do
    ~H"""
    <p class="truncate text-base font-semibold">{@title}</p>
    """
  end
end
