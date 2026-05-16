defmodule WatchClubWeb.Components.Navigation.Navbar.DesktopSearch do
  @moduledoc """
  Desktop search control for the navigation bar.

  Owner-private to `NavbarLive`. The hardcoded phx-* event names are global
  navbar events handled by the owning LiveComponent rather than reusable
  component API.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.ContentTypeIcon
  import WatchClubWeb.Components.Navigation.Navbar.SearchResults

  def desktop_search(assigns) do
    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".DesktopSearchHook">
        export default {
            mounted() {
          this.open = false
          this.input = document.getElementById("desktop-search-query");
          this.openOnFocus = () => this.setOpen(true)
          this.closeOnClickOutside = (e) => {
            if (this.el.contains(e.target)) return
            this.setOpen(false);
          }
          this.closeOnEscape = (e) => {
            if (e.key === "Escape" || e.key === "Tab") this.setOpen(false)
          }
          this.openOnInputChange = (e) => {
            this.setOpen(true)
          }
          this.input.addEventListener("focus", this.openOnFocus)
          this.input.addEventListener("input", this.openOnInputChange)
          document.addEventListener("mousedown", this.closeOnClickOutside)
          document.addEventListener("keydown", this.closeOnEscape)
        },
        updated() {
          // morphdom just stomped our attribute; put it back
          this.syncDom()
        },
        setOpen(v) {
          this.open = v
          this.syncDom()
        },
        syncDom() {
          if (this.open) this.el.setAttribute("data-open", "")
          else this.el.removeAttribute("data-open")
        },
        destroyed() {
          document.removeEventListener("mousedown", this.closeOnClickOutside)
          document.removeEventListener("keydown", this.closeOnEscape)
        }
      }
    </script>
    <%!--
      The hook owns only the client-side data-open attribute. The form inputs
      and search results remain LiveView-owned, so do not ignore the subtree.
    --%>
    <.form
      id="desktop-search-form"
      for={@form}
      layout="none"
      phx-change="preview_search"
      phx-submit="open_search"
      phx-target={@myself}
      phx-hook=".DesktopSearchHook"
      phx-mounted={JS.ignore_attributes("data-open")}
      class="hidden h-control-md md:block group/desktop-search relative"
    >
      <div class="absolute inset-x-0 top-0 overflow-hidden rounded-control border border-border bg-surface-inset transition-[border-color,box-shadow] focus-within:border-border-focus focus-within:ring-2 focus-within:ring-border-focus/40 group-data-open/desktop-search:z-50 group-data-open/desktop-search:shadow-overlay">
        <div class="flex w-full items-stretch">
          <.select
            field={@form[:location]}
            class="min-w-20 shrink-1"
            trigger_class="rounded-none border-0 border-r border-border-subtle shadow-none focus-visible:relative focus-visible:z-10 focus-visible:bg-surface-hover focus-visible:!border-border-subtle focus-visible:!ring-0"
          >
            <.select_item value="">
              <div class="flex h-icon min-w-0 items-center gap-related">
                <Lucideicons.globe class="size-icon shrink-0" />
                <span class="min-w-0 flex-1 truncate leading-none">
                  {dgettext("search", "Everywhere")}
                </span>
              </div>
            </.select_item>
            <.select_item
              :for={membership <- @current_user.memberships}
              value={membership.club.id}
            >
              <div class="flex h-icon min-w-0 items-center gap-related">
                <.avatar
                  id={membership.club.id}
                  name={membership.club.name}
                  size="xs"
                  class="shrink-0"
                />
                <span class="min-w-0 flex-1 truncate leading-none">
                  {membership.club.name}
                </span>
              </div>
            </.select_item>
          </.select>
          <.select
            field={@form[:content_type]}
            class="min-w-20 shrink-1"
            trigger_class="rounded-none border-0 border-r border-border-subtle shadow-none focus-visible:relative focus-visible:z-10 focus-visible:bg-surface-hover focus-visible:!border-border-subtle focus-visible:!ring-0"
          >
            <.select_item
              :for={content_type <- SearchContentType.values()}
              value={content_type}
            >
              <div class="flex h-icon min-w-0 items-center gap-related">
                <.content_type_icon type={content_type} class="size-icon shrink-0" />
                <span class="min-w-0 flex-1 truncate leading-none">
                  {SearchContentType.translated_label(content_type)}
                </span>
              </div>
            </.select_item>
          </.select>
          <.input
            id="desktop-search-query"
            field={@form[:query]}
            placeholder={placeholder(assigns)}
            class="min-w-48 h-control-md flex-1 rounded-none border-0 bg-surface-inset text-text shadow-none ring-0 placeholder:text-text-subtle focus-visible:bg-surface-hover focus-visible:!border-transparent focus-visible:!ring-0"
          />
          <button
            type="submit"
            aria-label={dgettext("search", "Search")}
            class="inline-flex h-control-md shrink-0 items-center justify-center border-l border-border-subtle bg-surface-inset px-group text-text-muted transition-colors hover:bg-surface-hover hover:text-text focus-visible:relative focus-visible:z-10 focus-visible:bg-surface-hover focus-visible:text-text focus-visible:!ring-0 focus-visible:outline-none"
          >
            <Lucideicons.search class="size-icon-sm" />
          </button>
        </div>
        <div
          id="desktop-search-preview"
          class="hidden min-h-0 divide-y divide-border-subtle overflow-y-auto border-t border-border-subtle bg-surface-inset group-data-open/desktop-search:block"
        >
          <.search_results {assigns} />
        </div>
      </div>
    </.form>
    """
  end

  defp placeholder(%{form: form, current_user: current_user}) do
    content_type = form[:content_type].value

    case form[:location].value do
      nil ->
        dgettext("search", "Search all %{content_type}",
          content_type: SearchContentType.translated_label(content_type)
        )

      location_id ->
        membership =
          Enum.find(
            current_user.memberships,
            &(&1.club.id ==
                location_id)
          )

        dgettext("search", "Search %{content_type} in %{club_name}",
          content_type: SearchContentType.translated_label(content_type),
          club_name: membership.club.name
        )
    end
  end
end
