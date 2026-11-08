defmodule WatchClubWeb.Components.Navigation.SearchFieldLive do
  @moduledoc """
  The search field of the app bar. While you type, a drop-down lists the first results; Enter
  opens the search page with every result. Up and Down move through the results. The In the
  library filter keeps only the Library. On the search page, the field shows the page's query and
  filter.

  On phones, the field is a filled pill, and the drop-down fills the screen, where the field's
  search icon becomes a back arrow: only that arrow, Escape or picking a result closes it, so
  hiding the keyboard doesn't.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Search.SearchResultRow
  import WatchClubWeb.Components.Search.SearchScopes
  import WatchClubWeb.Components.Search.SearchStatus

  alias WatchClub.Contents.SearchResultsPage

  @max_results 6

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, id: assigns.id, current_user: assigns.current_user)

    # The field follows the search page's query and filter when its URL changes, and keeps what
    # you type in between
    if socket.assigns[:current_url] == assigns.current_url do
      {:ok, socket}
    else
      {:ok,
       socket
       |> cancel_async(:search)
       |> assign(current_url: assigns.current_url, status: :idle)
       # Intentionally small: at most @max_results results
       |> assign(:results, [])
       |> assign(search_page_params(assigns.current_url))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".Combobox">
        export default {
          mounted() {
            this.input = this.el.querySelector("[role=combobox]")
            this.panel = this.el.querySelector("[data-results]")
            this.active = null
            this.options = () => [...this.el.querySelectorAll("[role=option]")]
            this.phone = () => window.matchMedia("(width < 48rem)").matches
            // Opened here rather than with phx-focus, which the input's phx-debounce would delay.
            // `data-open` makes it full screen on phones, closed by the back arrow (`data-cancel`).
            this.setOpen = (open) => {
              open ? this.js().show(this.panel) : this.js().hide(this.panel)
              this.js().setAttribute(this.input, "aria-expanded", open.toString())
              open ? this.js().setAttribute(this.el, "data-open", "") : this.js().removeAttribute(this.el, "data-open")
              document.body.style.overflow = open && this.phone() ? "hidden" : ""
              // Keeps keyboards and screen readers out of the page behind the full screen
              document.querySelectorAll("main, #tab-bar").forEach(el => el.inert = open && this.phone())
              if (!open) this.select(null)
            }
            this.el.querySelector("[data-cancel]").addEventListener("click", () => {
              this.input.value = ""
              this.input.dispatchEvent(new Event("input", {bubbles: true}))
              this.setOpen(false)
              this.input.blur()
            })
            this.select = (option) => {
              this.options().forEach(o => o.removeAttribute("aria-selected"))
              this.active = option ? option.id : null
              if (option) {
                option.setAttribute("aria-selected", "true")
                option.scrollIntoView({block: "nearest"})
                this.input.setAttribute("aria-activedescendant", option.id)
              } else {
                this.input.removeAttribute("aria-activedescendant")
              }
            }
            this.input.addEventListener("focus", () => {
              // On the search page, the field starts with the page's query but no results yet
              if (this.el.dataset.status === "idle" && this.input.value.trim()) {
                this.pushEventTo(this.el, "search", {query: this.input.value})
              }
              this.setOpen(true)
            })
            this.el.addEventListener("input", () => {
              this.select(null)
              this.setOpen(true)
            })
            // A click on the In the library filter, which some browsers don't focus, keeps the
            // drop-down open
            this.el.addEventListener("pointerdown", () => { this.pointerInside = true })
            document.addEventListener("pointerup", this.onPointerUp = () => { this.pointerInside = false })
            this.el.addEventListener("focusout", (e) => {
              if (this.phone()) return
              if (!this.pointerInside && !this.el.contains(e.relatedTarget)) this.setOpen(false)
            })
            this.el.addEventListener("click", (e) => {
              if (e.target.closest("a[role=option]")) this.setOpen(false)
            })
            this.input.addEventListener("keydown", (e) => {
              const options = this.options()
              if (e.key === "Escape") {
                this.setOpen(false)
              } else if (e.key === "ArrowDown" || e.key === "ArrowUp") {
                this.setOpen(true)
                if (!options.length) return
                e.preventDefault()
                let i = options.findIndex(o => o.id === this.active)
                i = e.key === "ArrowDown" ? (i + 1) % options.length : (i <= 0 ? options.length - 1 : i - 1)
                this.select(options[i])
              } else if (e.key === "Enter" && this.active) {
                const option = options.find(o => o.id === this.active)
                if (option) {
                  e.preventDefault()
                  option.click()
                }
              }
            })
          },
          updated() {
            // A patch drops the attributes that only this hook sets
            this.select(this.options().find(o => o.id === this.active))
          },
          destroyed() {
            document.removeEventListener("pointerup", this.onPointerUp)
            document.body.style.overflow = ""
            document.querySelectorAll("main, #tab-bar").forEach(el => el.inert = false)
          }
        }
      </script>
      <.form
        id={@id}
        for={to_form(%{})}
        layout="none"
        role="search"
        autocomplete="off"
        phx-hook=".Combobox"
        data-status={@status}
        phx-target={@myself}
        phx-change="search"
        phx-submit="open_search_page"
        class="group/combo relative max-md:data-open:fixed max-md:data-open:inset-0 max-md:data-open:flex max-md:data-open:flex-col max-md:data-open:bg-canvas"
      >
        <div class="flex items-center gap-related max-md:group-data-open/combo:h-(--wc-app-bar-height) max-md:group-data-open/combo:shrink-0 max-md:group-data-open/combo:px-page">
          <div class="relative max-md:min-w-0 max-md:flex-1">
            <label for={"#{@id}-input"} class="sr-only">
              {dgettext("search", "Search movies and TV shows")}
            </label>
            <Lucideicons.search class="pointer-events-none absolute top-1/2 left-3 size-icon-sm -translate-y-1/2 text-text-subtle max-md:group-data-open/combo:hidden" />
            <span class="absolute top-1/2 left-1 z-10 hidden -translate-y-1/2 max-md:group-data-open/combo:block">
              <.button
                id={"#{@id}-back"}
                variant="ghost"
                size="icon-sm"
                data-cancel
                aria-label={dgettext("search", "Close search")}
                class="rounded-full! text-text-muted!"
              >
                <Lucideicons.arrow_left />
              </.button>
            </span>
            <%!-- While the results are open, the field grows to their width on desktop. Phones
            give it the room the page's name leaves, as a filled pill --%>
            <.input
              id={"#{@id}-input"}
              name="query"
              value={@query}
              phx-debounce="300"
              placeholder={dgettext("search", "Search")}
              enterkeyhint="search"
              role="combobox"
              aria-expanded="false"
              aria-controls={"#{@id}-listbox"}
              aria-autocomplete="list"
              data-search-field
              class="peer w-56! pr-10! pl-9! transition-[width,border-color,box-shadow]! duration-200 aria-expanded:w-72! max-md:w-full! max-md:rounded-full! max-md:border-transparent! max-md:bg-surface-raised! max-md:focus-visible:ring-0! max-md:aria-expanded:w-full! @3xl/bar:w-72! @3xl/bar:aria-expanded:w-[min(32rem,calc(100cqw-2rem))]!"
            />
            <.kbd class="absolute top-1/2 right-2.5 -translate-y-1/2 peer-focus:hidden pointer-coarse:hidden">
              /
            </.kbd>
          </div>
        </div>

        <div
          id={"#{@id}-panel"}
          data-results
          class="absolute top-full right-0 z-40 mt-related hidden w-[min(32rem,calc(100cqw-2rem))] overflow-hidden rounded-card border border-border bg-surface-overlay shadow-overlay max-md:static max-md:mt-0 max-md:min-h-0 max-md:w-full max-md:flex-1 max-md:overflow-y-auto max-md:rounded-none max-md:border-0 max-md:bg-canvas max-md:shadow-none"
        >
          <div class="border-b border-border-subtle p-related max-md:px-page">
            <.search_scopes
              id={"#{@id}-scopes"}
              has_media={@has_media?}
              on_toggle={JS.push("toggle_has_media", target: @myself)}
            />
          </div>
          <div class="max-h-[min(32rem,calc(100svh-10rem))] overflow-y-auto max-md:max-h-none max-md:overflow-visible">
            <.search_status
              id={"#{@id}-status"}
              status={@status}
              query={@query}
              result_count={length(@results)}
              on_retry={JS.push("retry", target: @myself)}
            />
            <div
              :if={@status == :ok and @results != []}
              id={"#{@id}-listbox"}
              role="listbox"
              aria-label={dgettext("search", "Search results")}
              class="flex flex-col gap-px p-related"
            >
              <.search_result_row
                :for={result <- @results}
                id={"#{@id}-result-#{result.identity.type}-#{result.identity.external_id}"}
                result={result}
                role="option"
                tabindex="-1"
              />
              <button
                id={"#{@id}-see-all"}
                type="submit"
                role="option"
                tabindex="-1"
                class="sticky bottom-0 flex min-h-touch-target items-center gap-related rounded-control bg-surface-overlay px-related text-left text-sm text-text-muted transition-colors hover:bg-surface-hover hover:text-text aria-selected:bg-surface-hover aria-selected:text-text max-md:bg-canvas"
              >
                <span class="flex-1">
                  {raw(
                    dgettext("search", "See all results for %{query}",
                      query: gtspan("“#{@query}”", "font-semibold text-text")
                    )
                  )}
                </span>
                <.kbd class="pointer-coarse:hidden">↵</.kbd>
              </button>
            </div>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, socket |> assign(:query, query) |> search()}
  end

  def handle_event("retry", _params, socket) do
    {:noreply, search(socket)}
  end

  def handle_event("toggle_has_media", _params, socket) do
    {:noreply, socket |> update(:has_media?, &(!&1)) |> search()}
  end

  def handle_event("open_search_page", %{"query" => query}, socket) do
    case String.trim(query) do
      "" ->
        {:noreply, socket}

      query ->
        {:noreply, push_navigate(socket, to: Url.search_link(query, socket.assigns.has_media?))}
    end
  end

  defp search(socket) do
    %{query: query, has_media?: has_media?, current_user: user} = socket.assigns
    otel_context = OpenTelemetry.Ctx.get_current()

    case String.trim(query) do
      "" ->
        socket |> cancel_async(:search) |> assign(status: :idle, results: [])

      query ->
        socket
        |> assign(:status, :loading)
        |> start_async(:search, fn ->
          OpenTelemetry.Ctx.attach(otel_context)
          Contents.search_content!(%{query: query, has_media?: has_media?}, actor: user)
        end)
    end
  end

  @impl true
  def handle_async(:search, {:ok, %SearchResultsPage{results: results}}, socket) do
    {:noreply, assign(socket, status: :ok, results: Enum.take(results, @max_results))}
  end

  def handle_async(:search, {:exit, {:shutdown, :cancel}}, socket), do: {:noreply, socket}

  def handle_async(:search, {:exit, _reason}, socket) do
    {:noreply, assign(socket, status: :error, results: [])}
  end

  defp search_page_params(%Url{path: "/search", query: params}), do: Url.search_params(params)
  defp search_page_params(_current_url), do: Url.search_params(%{})
end
