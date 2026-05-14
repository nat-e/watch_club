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
    <.form
      id="desktop-search-form"
      for={@form}
      layout="none"
      phx-change="preview_search"
      phx-submit="open_search"
      phx-target={@myself}
      phx-hook=".DesktopSearchHook"
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
          <.search_overlay_results {assigns} />
        </div>
      </div>
    </.form>
    """
  end

  def mobile_search(assigns) do
    ~H"""
    <div class="flex md:hidden w-full flex-row justify-between items-center min-w-0">
      <h2 class="font-heading text-xl font-semibold">watch.club</h2>
      <.button
        class="block md:hidden shrink-0"
        variant="ghost"
        phx-click={
          JS.show(to: "#mobile-search-overlay", display: "flex")
          |> JS.focus(to: "#search-overlay-input")
        }
      >
        <Lucideicons.search class="size-icon-lg" />
      </.button>
      <.form
        id="mobile-search-overlay"
        for={@form}
        layout="none"
        phx-change="preview_search"
        phx-submit="open_search"
        phx-target={@myself}
        class="hidden flex-col z-50 fixed inset-0 bg-surface border-b border-border p-related"
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
                "flex p-group gap-group items-center w-full hover:bg-surface-hover",
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
              <Lucideicons.globe class="size-icon-lg" />{dgettext("search", "Everywhere")}
            </button>
            <button
              :for={membership <- @current_user.memberships}
              class={[
                "flex p-group gap-group items-center w-full hover:bg-surface-hover",
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
                "flex p-group gap-group items-center w-full hover:bg-surface-hover",
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
              <.content_type_icon type={content_type} class="size-icon" />{SearchContentType.translated_label(
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
    <.empty border={false} size="sm">
      <:icon>
        <Lucideicons.search />
      </:icon>
      <:description>
        {dgettext("search", "Start typing to search")}
      </:description>
    </.empty>
    """
  end

  defp search_overlay_results(%{search_results: nil} = assigns) do
    ~H"""
    <.empty border={false} size="sm">
      <:icon>
        <Lucideicons.triangle_alert />
      </:icon>
      <:description>
        {dgettext("search", "There was an error searching for your content")}
      </:description>
      <.button
        variant="secondary"
        size="sm"
        phx-target={@myself}
        phx-click="search"
      >
        {dgettext("default", "Try again")}
      </.button>
    </.empty>
    """
  end

  defp search_overlay_results(%{search_results: []} = assigns) do
    ~H"""
    <.empty border={false} size="sm">
      <:icon>
        <Lucideicons.search_x />
      </:icon>
      <:description>
        {dgettext("search", "We didn't find any content for your search")}
      </:description>
    </.empty>
    """
  end

  defp search_overlay_results(assigns) do
    ~H"""
    <.button
      class="shrink-0 flex justify-center p-related items-center w-full border-b-border rounded-none"
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
    <div class="border-b p-related">
      <.inline class="h-row-lg">
        <.button variant="ghost" size="icon" phx-click={JS.hide(to: "#mobile-search-overlay")}>
          <Lucideicons.arrow_left />
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
            class="peer h-control-md rounded-full bg-surface-inset p-group items-center pr-8 truncate"
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
      </.inline>
      <.cluster class="gap-x-group gap-y-related">
        <.input id="mobile-search-input-location" field={@form[:location]} class="hidden" />
        <.button
          variant="secondary"
          class="flex-1 gap-related min-w-38 items-center justify-between shrink"
          phx-click={
            JS.hide(to: "#mobile-overlay-search-content-type")
            |> JS.toggle(to: "#mobile-overlay-search-location")
          }
        >
          <.inline :if={@form[:location].value == nil}>
            <Lucideicons.globe class="size-icon" /> {dgettext("search", "Everywhere")}
          </.inline>

          <.inline :if={@form[:location].value != nil} class="min-w-0">
            <.avatar
              id={get_club(@current_user, @form[:location].value).id}
              name={get_club(@current_user, @form[:location].value).name}
              size="xs"
              class="shrink-0"
            />
            <span class="flex-1 truncate">
              {get_club(@current_user, @form[:location].value).name}
            </span>
          </.inline>
          <Lucideicons.chevron_down class="size-icon text-text-muted shrink-0" />
        </.button>
        <.input id="mobile-search-input-content-type" field={@form[:content_type]} class="hidden" />
        <.button
          variant="secondary"
          class="flex gap-related w-46 items-center justify-between"
          phx-click={
            JS.hide(to: "#mobile-overlay-search-location")
            |> JS.toggle(to: "#mobile-overlay-search-content-type")
          }
        >
          <.inline>
            <.content_type_icon type={@form[:content_type].value} class="size-icon" />
            {SearchContentType.translated_label(@form[:content_type].value)}
          </.inline>
          <Lucideicons.chevron_down class="size-icon text-text-muted" />
        </.button>
      </.cluster>
    </div>
    """
  end

  attr :content, ContentView, required: true

  defp search_preview_card(assigns) do
    ~H"""
    <.link class="flex gap-related hover:bg-surface-hover p-related" href={details_url(@content)}>
      <.tmdb_poster
        path={@content.image_path}
        size="w154"
        class="w-20 shrink-0 rounded-control"
      />
      <.stack space="related" class="h-full flex-1">
        <span class="font-bold">{search_preview_title(@content)}</span>
        <p class="line-clamp-2 text-sm text-text-muted">{@content.description}</p>
      </.stack>
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
