defmodule WatchClubWeb.Live.Nav.Components.Search do
  use WatchClubWeb, :component

  import WatchClubWeb.Components.{Contents, Images}

  alias WatchClub.Contents.ContentView

  def desktop_search(assigns) do
    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".DesktopSearchHook">
        export default {
            mounted() {
          this.open = false
          this.input = document.getElementById("desktop-search-query");
          this.popover = document.getElementById("desktop-search-preview");
          this.openOnFocus = () => this.setOpen(true)
          this.closeOnClickOutside = (e) => {
            if (e.target === this.input || this.popover.contains(e.target)) {
              this.setOpen(true);
              return
            }
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
    <.form
      id="desktop-search-form"
      for={@form}
      phx-change="preview_search"
      phx-submit="open_search"
      phx-target={@myself}
      phx-hook=".DesktopSearchHook"
      class="hidden sm:block group/desktop-search relative"
    >
      <div class="flex w-full items-stretch overflow-hidden rounded-control border border-border bg-surface-inset transition-colors group-data-open/desktop-search:rounded-b-none">
        <.select
          field={@form[:location]}
          class="w-48 shrink-0"
          trigger_class={[
            "h-control-md rounded-none border-0 border-r border-border-subtle bg-surface-inset shadow-none",
            "focus-visible:relative focus-visible:z-10 focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-border-focus/40"
          ]}
        >
          <.select_item value="">
            <div class="flex h-5 min-w-0 items-center gap-2">
              <Lucideicons.globe class="size-5 shrink-0" />
              <span class="min-w-0 flex-1 truncate leading-none">
                {dgettext("search", "Everywhere")}
              </span>
            </div>
          </.select_item>
          <.select_item
            :for={membership <- @current_user.memberships}
            value={membership.club.id}
          >
            <div class="flex h-5 min-w-0 items-center gap-2">
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
          class="w-44 shrink-0"
          trigger_class={[
            "h-control-md rounded-none border-0 border-r border-border-subtle bg-surface-inset shadow-none",
            "focus-visible:relative focus-visible:z-10 focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-border-focus/40"
          ]}
        >
          <.select_item
            :for={content_type <- SearchContentType.values()}
            value={content_type}
          >
            <div class="flex h-5 min-w-0 items-center gap-2">
              <.content_type_icon type={content_type} class="size-5 shrink-0" />
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
          class="h-control-md flex-1 rounded-none border-0 bg-surface-inset text-text shadow-none ring-0 placeholder:text-text-subtle focus-visible:border-transparent focus-visible:ring-0"
        />
        <button
          type="submit"
          aria-label={dgettext("search", "Search")}
          class="inline-flex h-control-md shrink-0 items-center justify-center border-l border-border-subtle bg-surface-inset px-3 text-text-muted transition-colors hover:bg-surface-hover hover:text-text focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-border-focus/40 focus-visible:outline-none"
        >
          <Lucideicons.search class="size-4" />
        </button>
      </div>
      <div
        id="desktop-search-preview"
        class="hidden group-data-open/desktop-search:block absolute z-50 w-full border border-t-0 border-border rounded-b-control bg-surface-inset divide-y divide-border-subtle shadow-overlay overflow-y-auto min-h-0"
      >
        <.search_overlay_results {assigns} />
      </div>
    </.form>
    """
  end

  def mobile_search(assigns) do
    ~H"""
    <div class="flex sm:hidden w-full flex-row justify-between items-center min-w-0">
      <h2 class="m-2 truncate min-w-0">watch.club</h2>
      <.button
        class="block sm:hidden shrink-0"
        variant="ghost"
        phx-click={
          JS.show(to: "#mobile-search-overlay", display: "flex")
          |> JS.focus(to: "#search-overlay-input")
        }
      >
        <Lucideicons.search class="size-6" />
      </.button>
      <.form
        id="mobile-search-overlay"
        for={@form}
        phx-change="preview_search"
        phx-submit="open_search"
        phx-target={@myself}
        class="hidden flex-col z-50 fixed inset-0 bg-surface border-b border-border p-2"
      >
        <.search_overlay_header
          current_user={@current_user}
          myself={@myself}
          form={@form}
        />
        <div class="relative flex-1 flex flex-col min-h-0">
          <div class="flex-1 divide-y overflow-y-auto min-h-0">
            <.search_overlay_results
              myself={@myself}
              form={@form}
              search_results={@search_results}
            />
          </div>
          <div id="mobile-overlay-search-location" class="hidden absolute inset-0 bg-surface">
            <button
              class={[
                "flex p-4 gap-4 items-center w-full hover:bg-surface-hover",
                @form[:location].value == nil && "bg-surface-selected"
              ]}
              phx-click={
                hide_overlay_and_change_value(
                  "#mobile-overlay-search-location",
                  "#mobile-search-input-location",
                  ""
                )
              }
              phx-target={@myself}
            >
              <Lucideicons.globe class="size-6" />{dgettext("search", "Everywhere")}
            </button>
            <button
              :for={membership <- @current_user.memberships}
              class={[
                "flex p-4 gap-4 items-center w-full hover:bg-surface-hover",
                @form[:location].value == membership.club.id &&
                  "bg-surface-selected"
              ]}
              phx-click={
                hide_overlay_and_change_value(
                  "#mobile-overlay-search-location",
                  "#mobile-search-input-location",
                  membership.club.id
                )
              }
              phx-target={@myself}
            >
              <.avatar
                :if={membership.club}
                id={membership.club.id}
                name={membership.club.name}
                size="sm"
              />
              <span class="truncate">{membership.club.name}</span>
            </button>
          </div>
          <div
            id="mobile-overlay-search-content-type"
            class="hidden h-full absolute inset-0 bg-surface"
          >
            <button
              :for={content_type <- SearchContentType.values()}
              class={[
                "flex p-4 gap-4 items-center w-full hover:bg-surface-hover",
                @form[:content_type].value == content_type &&
                  "bg-surface-selected"
              ]}
              phx-click={
                hide_overlay_and_change_value(
                  "#mobile-overlay-search-content-type",
                  "#mobile-search-input-content-type",
                  content_type
                )
              }
              phx-target={@myself}
            >
              <.content_type_icon type={content_type} class="size-5" />{SearchContentType.translated_label(
                content_type
              )}
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp search_overlay_results(%{search_results: nil, form: %{errors: []}} = assigns) do
    ~H"""
    <div class="flex w-fulll items-center p-4 gap-2 justify-center">
      <Lucideicons.search size="8" />
      <p>{dgettext("search", "Start typing to search")}</p>
    </div>
    """
  end

  defp search_overlay_results(%{search_results: nil} = assigns) do
    ~H"""
    <div class="flex flex-col items-center p-4 gap-2">
      <Lucideicons.triangle_alert size="8" />
      <p>{dgettext("search", "There was an error searching for your content")}</p>
      <.button
        variant="secondary"
        size="sm"
        phx-target={@myself}
        phx-click="search"
      >
        {dgettext("default", "Try again")}
      </.button>
    </div>
    """
  end

  defp search_overlay_results(%{search_results: []} = assigns) do
    ~H"""
    <div class="flex flex-col items-center p-4 gap-2">
      <Lucideicons.search_x size="8" />
      <p>{dgettext("search", "We didn't find any content for your search")}</p>
    </div>
    """
  end

  defp search_overlay_results(assigns) do
    ~H"""
    <.button
      class="shrink-0 flex justify-center p-2 items-center w-full border-b-border rounded-none"
      type="submit"
      variant="ghost"
    >
      <span>
        {dgettext("search", "See all results")}
        <.kbd>Enter ⏎</.kbd>
      </span>
      <Lucideicons.chevron_right />
    </.button>
    <.search_preview_card :for={result <- @search_results} content={result} />
    """
  end

  defp search_overlay_header(assigns) do
    ~H"""
    <div class="border-b p-2">
      <div class="flex h-16 items-center gap-2">
        <.button variant="ghost" size="icon" phx-click={JS.hide(to: "#mobile-search-overlay")}>
          <Lucideicons.arrow_left class="size-5" />
        </.button>
        <div
          class="relative flex-1"
          phx-click={
            JS.hide(to: "#mobile-overlay-search-location")
            |> JS.hide(to: "#mobile-overlay-search-content-type")
          }
        >
          <.input
            field={@form[:query]}
            placeholder={placeholder(assigns)}
            class="peer rounded-full bg-surface-inset p-4 h-10 items-center pr-8 truncate"
            phx-debounce="300"
          />
          <.button
            type="reset"
            variant="ghost"
            size="icon-sm"
            class="absolute right-2 top-1 peer-placeholder-shown:hidden"
            phx-click={JS.dispatch("change", to: "#overlay-search-form")}
          >
            <Lucideicons.x />
          </.button>
        </div>
      </div>
      <div class="gap-x-4 gap-y-2 flex flex-wrap">
        <.input id="mobile-search-input-location" field={@form[:location]} class="hidden" />
        <.button
          variant="secondary"
          class="flex-1 gap-2 min-w-38 items-center justify-between shrink"
          phx-click={
            JS.hide(to: "#mobile-overlay-search-content-type")
            |> JS.toggle(to: "#mobile-overlay-search-location")
          }
        >
          <div :if={@form[:location].value == nil} class="flex gap-2">
            <Lucideicons.globe class="size-5" /> {dgettext("search", "Everywhere")}
          </div>

          <div :if={@form[:location].value != nil} class="flex gap-2 min-w-0">
            <.avatar
              id={get_club(@current_user, @form[:location].value).id}
              name={get_club(@current_user, @form[:location].value).name}
              size="xs"
              class="shrink-0"
            />
            <span class="flex-1 truncate">
              {get_club(@current_user, @form[:location].value).name}
            </span>
          </div>
          <Lucideicons.chevron_down class="size-5 text-text-muted shrink-0" />
        </.button>
        <.input id="mobile-search-input-content-type" field={@form[:content_type]} class="hidden" />
        <.button
          variant="secondary"
          class="flex gap-2 w-46 items-center justify-between"
          phx-click={
            JS.hide(to: "#mobile-overlay-search-location")
            |> JS.toggle(to: "#mobile-overlay-search-content-type")
          }
        >
          <div class="flex gap-2">
            <.content_type_icon type={@form[:content_type].value} class="size-5" />
            {SearchContentType.translated_label(@form[:content_type].value)}
          </div>
          <Lucideicons.chevron_down class="size-5 text-text-muted" />
        </.button>
      </div>
    </div>
    """
  end

  attr :content, ContentView, required: true

  defp search_preview_card(assigns) do
    ~H"""
    <.link class="flex gap-2 hover:bg-surface-hover p-2" href={details_url(@content)}>
      <.tmdb_poster
        path={@content.image_path}
        size="w154"
        class="rounded-md w-20 shrink-0"
      />
      <div class="flex flex-col h-full gap-2 flex-1">
        <span class="font-bold">{search_preview_title(@content)}</span>
        <p class="text-text-muted line-clamp-2 text-sm">{@content.description}</p>
      </div>
    </.link>
    """
  end

  defp search_preview_title(%ContentView{title: title, release_date: nil}), do: title

  defp search_preview_title(%ContentView{title: title, release_date: date}),
    do: "#{title} (#{date.year})"

  defp get_club(current_user, club_id) do
    %Membership{} = m = Enum.find(current_user.memberships, fn m -> m.club.id == club_id end)
    m.club
  end

  defp details_url(%ContentView{type: :movie} = movie), do: ~p"/movies/#{movie.external_id}"
  defp details_url(%ContentView{type: :tv_show} = show), do: ~p"/shows/#{show.external_id}"

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

  defp hide_overlay_and_change_value(overlay_selector, field_selector, value) do
    JS.hide(to: overlay_selector)
    |> JS.set_attribute({"value", value},
      to: field_selector
    )
    |> JS.dispatch("input", to: field_selector)
    |> JS.focus(to: "#search-overlay-input")
  end
end
