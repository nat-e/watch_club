defmodule WatchClubWeb.Components.Navigation.SearchFieldLive do
  @moduledoc """
  The search field of the app bar. While you type, a drop-down lists the first results; Enter
  opens the search page with every result. Up and Down move through the results. On the search
  page, the field shows the page's query.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Search.SearchResultRow
  import WatchClubWeb.Components.Search.SearchScopes
  import WatchClubWeb.Components.Search.SearchStatus

  alias WatchClub.Contents.SearchResultsPage

  @max_results 6

  @impl true
  def mount(socket) do
    # Intentionally small: at most @max_results results
    {:ok, assign(socket, status: :idle, results: [])}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(id: assigns.id, current_user: assigns.current_user)
     |> assign_new(:query, fn -> search_page_query(assigns.current_url) end)}
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
            // Opened here rather than with phx-focus, which the input's phx-debounce would delay
            this.setOpen = (open) => {
              open ? this.js().show(this.panel) : this.js().hide(this.panel)
              this.js().setAttribute(this.input, "aria-expanded", open.toString())
              if (!open) this.select(null)
            }
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
            this.el.addEventListener("focusout", (e) => {
              if (!this.el.contains(e.relatedTarget)) this.setOpen(false)
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
        class="relative"
      >
        <label for={"#{@id}-input"} class="sr-only">
          {dgettext("search", "Search movies and TV shows")}
        </label>
        <Lucideicons.search class="pointer-events-none absolute top-1/2 left-3 size-icon-sm -translate-y-1/2 text-text-subtle" />
        <%!-- While the results are open, the field grows to their width on desktop --%>
        <.input
          id={"#{@id}-input"}
          name="query"
          value={@query}
          phx-debounce="300"
          placeholder={dgettext("search", "Search")}
          role="combobox"
          aria-expanded="false"
          aria-controls={"#{@id}-listbox"}
          aria-autocomplete="list"
          data-search-field
          class="peer w-56! pr-10! pl-9! transition-[width,border-color,box-shadow]! duration-200 aria-expanded:w-72! @3xl/bar:w-72! @3xl/bar:aria-expanded:w-[min(32rem,calc(100cqw-2rem))]!"
        />
        <.kbd class="absolute top-1/2 right-2.5 -translate-y-1/2 peer-focus:hidden pointer-coarse:hidden">
          /
        </.kbd>

        <div
          id={"#{@id}-panel"}
          data-results
          class="absolute top-full right-0 z-40 mt-related hidden w-[min(32rem,calc(100cqw-2rem))] overflow-hidden rounded-card border border-border bg-surface-overlay shadow-overlay"
        >
          <div class="border-b border-border-subtle p-related">
            <.search_scopes id={"#{@id}-scopes"} />
          </div>
          <div class="max-h-[min(32rem,calc(100svh-10rem))] overflow-y-auto">
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
                class="sticky bottom-0 flex min-h-touch-target items-center gap-related rounded-control bg-surface-overlay px-related text-left text-sm text-text-muted transition-colors hover:bg-surface-hover hover:text-text aria-selected:bg-surface-hover aria-selected:text-text"
              >
                <span class="flex-1">
                  {raw(
                    dgettext("search", "See all results for %{query}",
                      query: gtspan("“#{@query}”", "font-semibold text-text")
                    )
                  )}
                </span>
                <.kbd>↵</.kbd>
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

  def handle_event("open_search_page", %{"query" => query}, socket) do
    case String.trim(query) do
      "" -> {:noreply, socket}
      query -> {:noreply, push_navigate(socket, to: ~p"/search?#{%{query: query}}")}
    end
  end

  defp search(socket) do
    %{query: query, current_user: user} = socket.assigns

    case String.trim(query) do
      "" ->
        socket |> cancel_async(:search) |> assign(status: :idle, results: [])

      query ->
        socket
        |> assign(:status, :loading)
        |> start_async(:search, fn ->
          Contents.search_content!(%{query: query}, actor: user)
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

  defp search_page_query(%Url{path: "/search", query: %{"query" => query}}), do: query
  defp search_page_query(_current_url), do: ""
end
