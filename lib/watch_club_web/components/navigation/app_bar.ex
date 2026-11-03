defmodule WatchClubWeb.Components.Navigation.AppBar do
  @moduledoc """
  The bar at the top of `WatchClubWeb.Layouts.app/1`, which owns its contract.

  On desktop: back, the page's breadcrumb or name and the search field. On phones: back, the
  instance name and the user's avatar, which opens the account page. `/` or Cmd/Ctrl+K focuses the visible search field, the bar's or the search page's.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Navigation.AccountMenu

  alias WatchClubWeb.Components.Navigation.SearchFieldLive

  attr :title, :string, required: true
  attr :content_page?, :boolean, required: true
  attr :icon, :list, required: true, doc: "the `:icon` slot of `Layouts.app`"
  attr :parent, :list, required: true, doc: "the `:parent` slot of `Layouts.app`"
  attr :current_url, Url, required: true
  attr :current_user, User, required: true
  attr :instance_settings, InstanceSettings, required: true

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
        "group/bar @container/bar sticky top-0 z-20 flex h-(--wc-app-bar-height) items-center gap-tight border-b pr-related transition-colors duration-200 md:gap-group md:px-page",
        @back && "pl-tight",
        !@back && "pl-page",
        @content_page? &&
          "border-transparent bg-transparent data-scrolled:border-border-subtle data-scrolled:bg-canvas",
        !@content_page? &&
          "border-transparent bg-canvas data-scrolled:border-border-subtle md:border-border-subtle"
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

      <div class="flex min-w-0 flex-1 items-center max-md:hidden">
        <.location title={@title} content_page?={@content_page?} icon={@icon} parent={@parent} />
      </div>
      <.link
        id="app-bar-instance-link"
        navigate={~p"/"}
        class="min-w-0 truncate rounded-control font-heading text-base font-semibold md:hidden"
      >
        {@instance_settings.name}
      </.link>

      <div class="ml-auto flex shrink-0 items-center gap-related">
        <div class="max-md:hidden">
          <.live_component
            module={SearchFieldLive}
            id="app-bar-search"
            current_url={@current_url}
            current_user={@current_user}
          />
        </div>

        <.button
          id="app-bar-account-button"
          variant="ghost"
          size="icon"
          class="rounded-full! md:hidden pointer-coarse:size-touch-target!"
          aria-label={dgettext("nav", "Account")}
          aria-haspopup="dialog"
          aria-controls="account-page"
          commandfor="account-page"
          command="show-modal"
        >
          <.avatar id={@current_user.id} name={@current_user.username} size="md" />
        </.button>
      </div>
    </header>

    <.account_page id="account-page" user={@current_user} />
    """
  end

  # A child page goes up to its parent. A Content page goes back to the previous page, or Home
  # when the history has no previous page of the app: see the hook.
  defp back([parent], _content_page?) do
    label = dgettext("nav", "Back to %{page}", page: parent.label)
    %{navigate: parent.navigate, label: label, history?: false}
  end

  defp back([], true), do: %{navigate: ~p"/", label: dgettext("nav", "Back"), history?: true}
  defp back([], false), do: nil

  attr :title, :string, required: true
  attr :content_page?, :boolean, required: true
  attr :icon, :list, required: true
  attr :parent, :list, required: true

  defp location(%{parent: [parent]} = assigns) do
    assigns = assign(assigns, :parent, parent)

    ~H"""
    <nav aria-label={dgettext("nav", "Breadcrumb")} class="min-w-0">
      <ol class="flex min-w-0 list-none items-center gap-related p-0 text-sm">
        <li class="min-w-0 shrink">
          <.link
            id="app-bar-parent-link"
            navigate={@parent.navigate}
            class="flex min-w-0 items-center gap-related rounded-control font-semibold text-text-muted transition-colors hover:text-text [&_svg]:size-icon-sm [&_svg]:shrink-0"
          >
            {render_slot(@parent)}
            <span class="truncate">{@parent.label}</span>
          </.link>
        </li>
        <li aria-hidden="true">
          <Lucideicons.chevron_right class="size-icon-sm text-text-subtle" />
        </li>
        <li
          aria-current="page"
          class="flex min-w-0 items-center gap-related font-semibold text-text [&_svg]:size-icon-sm [&_svg]:shrink-0 [&_svg]:text-text-muted"
        >
          {render_slot(@icon)}
          <span class="truncate">{@title}</span>
        </li>
      </ol>
    </nav>
    """
  end

  # The page shows its title in its hero: the bar shows it once the hero's title scrolls away.
  defp location(%{content_page?: true} = assigns) do
    ~H"""
    <p
      aria-hidden="true"
      class="truncate text-base font-semibold opacity-0 transition-opacity duration-200 group-data-past-title/bar:opacity-100"
    >
      {@title}
    </p>
    """
  end

  defp location(assigns) do
    ~H"""
    <p class="flex min-w-0 items-center gap-related [&_svg]:size-icon-sm [&_svg]:shrink-0 [&_svg]:text-text-muted">
      {render_slot(@icon)}
      <span class="truncate text-base font-semibold">{@title}</span>
    </p>
    """
  end
end
