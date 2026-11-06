defmodule WatchClubWeb.BrowsePage do
  @moduledoc """
  Browse: the Library's posters, with a row of filters and a sort menu. Filters and the sort live
  in the URL, so Back undoes them. Signing in opens it.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.ContentTypeIcon
  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.{Content, LibrarySort}
  alias WatchClub.History.WatchProgress
  alias WatchClub.Languages
  alias WatchClub.MediaCatalog.Media
  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive
  alias WatchClubWeb.Helpers.KeysetStreamState

  @page_size 40
  # Pages leave out `added_to_library_at`: with the Title sort, it empties the next page (WC-51)
  @content_fields [:implementation, :actor_progress_status]
  @no_filters %{type: nil, not_watched?: false, decades: [], original_languages: []}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      title={dgettext("nav", "Browse")}
      search
      class="@container pt-group!"
    >
      <div class="flex min-w-0 items-center gap-related">
        <.scroll_row id="filters" variant="chips" class="min-w-0 flex-1">
          <.filter_chip
            :for={type <- [nil | ContentType.library_display_order()]}
            id={"filter-type-#{type || "all"}"}
            on={@filters.type == type}
            phx-click="toggle_filter"
            phx-value-filter="type"
            phx-value-choice={type}
          >
            <:icon :if={type}><.content_type_icon type={type} /></:icon>
            {ContentType.translated_plural_label(type)}
          </.filter_chip>
          <.divider />
          <.filter_chip
            id="filter-not-watched"
            on={@filters.not_watched?}
            phx-click="toggle_filter"
            phx-value-filter="not_watched"
          >
            <:icon><Lucideicons.eye_off /></:icon>
            {dgettext("browse", "Not watched")}
          </.filter_chip>
          <.divider />
          <.more_button filters={@filters} />
        </.scroll_row>
        <.sort_menu filters={@filters} sort={@sort} />
      </div>

      <ul
        id="library"
        phx-update="stream"
        class="grid list-none grid-cols-3 gap-x-related gap-y-group p-0 @lg:grid-cols-[repeat(auto-fill,minmax(8.5rem,1fr))] @lg:gap-x-group"
      >
        <%!-- Shown only when it's the stream's sole child --%>
        <li id="library-empty" class="col-span-full hidden only:block">
          <.empty :if={filtered?(@filters)}>
            <:icon><Lucideicons.funnel_x /></:icon>
            <:title>{dgettext("browse", "Nothing matches these filters")}</:title>
            <:description>{dgettext("browse", "Remove a filter to see more.")}</:description>
            <.button id="library-clear-filters" variant="secondary" patch={clear_filters_path(@sort)}>
              {dgettext("browse", "Clear filters")}
            </.button>
          </.empty>
          <.empty :if={not filtered?(@filters)}>
            <:icon><Lucideicons.clapperboard /></:icon>
            <:title>{dgettext("browse", "Nothing in the library yet")}</:title>
            <:description>
              {dgettext("browse", "Movies and TV shows show up here once they're on the server.")}
            </:description>
          </.empty>
        </li>
        <li :for={{dom_id, content} <- @streams.library} id={dom_id}>
          <.poster_card content={content} current_user={@current_user} />
        </li>
      </ul>

      <.infinite_scroll_trigger
        :if={KeysetStreamState.can_load_more?(@stream_state)}
        id="library-load-more"
        event="load_more"
      />

      <.more_filters
        :if={@filter_options}
        filters={@filters}
        sort={@sort}
        options={@filter_options}
      />
    </Layouts.app>
    """
  end

  # Between the type chips, Not watched and More
  defp divider(assigns) do
    ~H"""
    <span class="h-6 w-px shrink-0 bg-border" aria-hidden="true"></span>
    """
  end

  attr :filters, :map, required: true

  # Opens the decades and original languages, with how many of them are on
  defp more_button(assigns) do
    assigns =
      assign(
        assigns,
        :count,
        Enum.count([assigns.filters.decades, assigns.filters.original_languages], &(&1 != []))
      )

    ~H"""
    <.button
      id="more-filters-button"
      variant="secondary"
      size="sm"
      phx-click="open_more_filters"
      aria-haspopup="dialog"
      aria-label={
        if @count > 0,
          do: dngettext("browse", "More filters, %{count} on", "More filters, %{count} on", @count),
          else: dgettext("browse", "More filters")
      }
      class="shrink-0 rounded-full! text-sm!"
    >
      <:icon><Lucideicons.sliders_horizontal class="size-icon-sm" /></:icon>
      {dgettext("browse", "More")}
      <.badge :if={@count > 0} size="sm">{@count}</.badge>
    </.button>
    """
  end

  attr :filters, :map, required: true
  attr :sort, :atom, required: true, doc: "a `LibrarySort`"

  # Its name where there's room, only its icon on phones
  defp sort_menu(assigns) do
    ~H"""
    <.dropdown_menu id="sort" class="shrink-0">
      <:trigger>
        <.button
          id="sort-button"
          variant="secondary"
          size="sm"
          aria-label={dgettext("browse", "Sort: %{sort}", sort: LibrarySort.translated_label(@sort))}
          class="rounded-full! text-sm! @max-2xl:px-related!"
        >
          <:icon><Lucideicons.arrow_down_up class="size-icon-sm" /></:icon>
          <span class="@max-2xl:sr-only">{LibrarySort.translated_label(@sort)}</span>
        </.button>
      </:trigger>
      <.dropdown_menu_item
        :for={sort <- LibrarySort.values()}
        id={"sort-#{sort}"}
        patch={browse_path(@filters, sort)}
        checked={@sort == sort}
      >
        {LibrarySort.translated_label(sort)}
      </.dropdown_menu_item>
    </.dropdown_menu>
    """
  end

  attr :filters, :map, required: true
  attr :sort, :atom, required: true, doc: "a `LibrarySort`"
  attr :options, :map, required: true, doc: "the Library's decades and original languages"

  # From the bottom of the screen on phones. Each choice applies at once, and the dialog scrolls,
  # so its footer stays at its bottom.
  defp more_filters(assigns) do
    ~H"""
    <.modal
      id="more-filters"
      size="md"
      sheet
      on_close={JS.push("close_more_filters")}
      class="[&>[data-slot=modal-content]]:overflow-visible"
    >
      <:title>{dgettext("browse", "Filters")}</:title>
      <fieldset class="flex min-w-0 flex-col gap-related">
        <legend class="mb-related"><.text_label text={dgettext("browse", "Year")} /></legend>
        <div class="flex flex-wrap gap-related">
          <.filter_chip
            :for={decade <- @options.decades}
            id={"filter-decade-#{decade}"}
            on={decade in @filters.decades}
            phx-click="toggle_filter"
            phx-value-filter="decade"
            phx-value-choice={decade}
            class="tabular-nums"
          >
            {dgettext("browse", "%{decade}s", decade: decade)}
          </.filter_chip>
        </div>
      </fieldset>
      <fieldset class="flex min-w-0 flex-col">
        <legend class="mb-related">
          <.text_label text={dgettext("browse", "Original language")} />
        </legend>
        <label
          :for={language <- @options.original_languages}
          class="-mx-related flex items-center gap-related rounded-control px-related py-tight text-sm text-text-muted transition-colors hover:bg-surface-hover hover:text-text has-checked:text-text pointer-coarse:min-h-touch-target"
        >
          <.checkbox
            id={"filter-language-#{language}"}
            checked={language in @filters.original_languages}
            phx-click="toggle_filter"
            phx-value-filter="language"
            phx-value-choice={language}
          />
          <span class="text-base leading-none" aria-hidden="true">
            {Languages.to_flag(language)}
          </span>
          <span class="min-w-0 truncate">{Languages.to_name(language)}</span>
        </label>
      </fieldset>
      <:footer class="sticky bottom-0 -mx-cluster -mb-cluster flex-row! items-center justify-between! border-t border-border-subtle bg-surface-overlay px-cluster py-group">
        <.button
          id="more-filters-clear"
          variant="ghost"
          patch={clear_filters_path(@sort)}
          disabled={not filtered?(@filters)}
        >
          {dgettext("browse", "Clear all")}
        </.button>
        <.button id="more-filters-done" data-modal-close>
          {dgettext("browse", "Done")}
        </.button>
      </:footer>
    </.modal>
    """
  end

  attr :content, Content, required: true
  attr :current_user, User, required: true

  # Its progress badge, and on hover its name, original language, year and Play
  defp poster_card(assigns) do
    assigns =
      assigns
      |> assign(:title, assigns.content.implementation.best_localization.title)
      |> assign(:identity, ContentIdentity.from_content(assigns.content))
      |> assign(:progress_id, "progress-#{assigns.content.id}")

    ~H"""
    <div class="group relative">
      <.tmdb_poster
        path={@content.implementation.best_localization.poster_path}
        size="w342"
        class="w-full shadow-card"
      >
        <.progress_badge id={@progress_id} status={@content.actor_progress_status} />
        <span
          aria-hidden="true"
          class="absolute inset-0 flex flex-col justify-end gap-related bg-linear-to-t from-black/90 via-black/60 to-transparent p-related opacity-0 transition-opacity duration-200 group-focus-within:opacity-100 group-hover:opacity-100"
        >
          <span class="line-clamp-3 text-sm font-semibold text-white">{@title}</span>
          <span class="flex items-center gap-related text-xs text-white/80">
            <span
              :if={@content.original_language}
              class="text-base leading-none"
              title={
                dgettext("browse", "Original language: %{language}",
                  language: Languages.to_name(@content.original_language)
                )
              }
            >
              {Languages.to_flag(@content.original_language)}
            </span>
            <span :if={@content.release_date}>{@content.release_date.year}</span>
          </span>
        </span>
      </.tmdb_poster>
      <.link
        navigate={Url.content_details_link(@identity)}
        aria-label={@title}
        aria-describedby={
          @content.actor_progress_status in [:completed, :in_progress] && @progress_id
        }
        class="absolute inset-0 rounded-lg"
      ></.link>
      <%!-- Screens that can't hover have no Play: a tap opens the title --%>
      <div class="pointer-events-none absolute inset-0 grid place-items-center opacity-0 transition-opacity duration-200 group-focus-within:opacity-100 group-hover:opacity-100 [@media(hover:none)]:hidden">
        <.live_component
          id={PlayOrRequestButtonLive.dom_id(@identity)}
          module={PlayOrRequestButtonLive}
          content_identity={@identity}
          current_user={@current_user}
          variant="round"
          class="pointer-events-auto"
        />
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :status, :atom, required: true, doc: "a `WatchStatus`"

  # Watched or in progress
  defp progress_badge(assigns) do
    ~H"""
    <span
      :if={@status in [:completed, :in_progress]}
      id={@id}
      role="img"
      aria-label={WatchStatus.translated_label(@status)}
      title={WatchStatus.translated_label(@status)}
      class="absolute top-related right-related grid size-7 place-items-center rounded-full bg-black/80"
    >
      <Lucideicons.check :if={@status == :completed} class="size-icon-sm text-success" />
      <Lucideicons.contrast :if={@status == :in_progress} class="size-icon-sm text-primary" />
    </span>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     # More's decades and original languages while it's open, as they were when it opened
     |> assign(:filter_options, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:filters, filters(params))
     |> assign(
       :sort,
       Url.parse_url_param(params["sort"], LibrarySort.values(), LibrarySort.default())
     )
     |> assign(:stream_state, KeysetStreamState.init(@page_size))
     |> load_page!()}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    if KeysetStreamState.can_load_more?(socket.assigns.stream_state) do
      {:noreply, load_page!(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("open_more_filters", _params, socket) do
    {:noreply,
     assign(
       socket,
       :filter_options,
       Contents.get_library_filter_options!(actor: socket.assigns.current_user)
     )}
  end

  def handle_event("close_more_filters", _params, socket) do
    {:noreply, assign(socket, :filter_options, nil)}
  end

  # Changes the filters from the server's own state, so quick taps all count
  def handle_event("toggle_filter", %{"filter" => filter} = params, socket) do
    %{filters: filters, sort: sort} = socket.assigns

    {:noreply,
     push_patch(socket, to: browse_path(toggle_filter(filters, filter, params["choice"]), sort))}
  end

  @impl true
  def handle_info(%Notification{} = notification, socket) do
    PlayOrRequestButtonLive.handle_pubsub_message(notification, socket.assigns.current_user)

    case notification do
      %{resource: Media, action: %{type: :create}, data: media, metadata: %{content_id: id}} ->
        {:noreply, update_poster!(socket, id, media.inserted_at)}

      %{resource: Media, metadata: %{content_id: id}} ->
        {:noreply, update_poster!(socket, id)}

      %{resource: Content, data: %Content{id: id}} ->
        {:noreply, update_poster!(socket, id)}

      %{resource: WatchProgress, metadata: %{content_id: id}} ->
        {:noreply, update_poster!(socket, id)}

      _other ->
        {:noreply, socket}
    end
  end

  # The filters in the URL. Unknown types and decades that aren't numbers are left out.
  defp filters(params) do
    %{
      type: Url.parse_url_param(params["type"], ContentType.library_display_order()),
      not_watched?: params["not_watched"] == "true",
      decades:
        params["decades"]
        |> list_param()
        |> Enum.flat_map(fn decade ->
          case Integer.parse(decade) do
            {decade, ""} -> [decade]
            _not_a_number -> []
          end
        end),
      original_languages: list_param(params["languages"])
    }
  end

  defp list_param(values) when is_binary(values), do: String.split(values, ",", trim: true)
  # Missing, or a list from a hand-edited URL such as `decades[]=1990`
  defp list_param(_values), do: []

  # The type that's on goes back to All
  defp toggle_filter(filters, "type", type) do
    type = Url.parse_url_param(type, ContentType.library_display_order())
    %{filters | type: if(type == filters.type, do: nil, else: type)}
  end

  defp toggle_filter(filters, "not_watched", _value),
    do: %{filters | not_watched?: not filters.not_watched?}

  defp toggle_filter(filters, "decade", decade),
    do: %{filters | decades: toggle_choice(filters.decades, String.to_integer(decade))}

  defp toggle_filter(filters, "language", language),
    do: %{filters | original_languages: toggle_choice(filters.original_languages, language)}

  defp toggle_choice(choices, choice) do
    if choice in choices, do: List.delete(choices, choice), else: choices ++ [choice]
  end

  # Browse's URL with these filters and sort, without the ones that are off
  defp browse_path(filters, sort) do
    params =
      Enum.reject(
        [
          type: filters.type,
          not_watched: filters.not_watched?,
          decades: Enum.join(filters.decades, ","),
          languages: Enum.join(filters.original_languages, ","),
          sort: sort != LibrarySort.default() && sort
        ],
        fn {_param, value} -> value in [nil, false, ""] end
      )

    ~p"/?#{params}"
  end

  defp clear_filters_path(sort), do: browse_path(@no_filters, sort)

  defp filtered?(filters), do: filters != @no_filters

  defp load_page!(socket) do
    %{stream_state: stream_state, filters: filters, sort: sort, current_user: user} =
      socket.assigns

    {:ok, new_state, contents} =
      KeysetStreamState.load_page(stream_state, fn page_options ->
        Contents.get_contents_in_library(Map.put(filters, :sort, sort),
          load: @content_fields,
          page: page_options,
          actor: user
        )
      end)

    socket
    |> assign(:stream_state, new_state)
    |> stream(:library, contents, reset: stream_state.status == :init)
  end

  # With the Recently added sort, a Content that joins the Library goes first. One that no longer
  # matches the filters goes, and the others update in place if they're loaded.
  defp update_poster!(socket, content_id, new_media_added_at \\ nil) do
    %{filters: filters, sort: sort, current_user: user} = socket.assigns

    case Contents.get_contents_in_library!(filters,
           query: [filter: [id: content_id]],
           load: [:added_to_library_at | @content_fields],
           actor: user
         ) do
      [] ->
        stream_delete_by_dom_id(socket, :library, "library-#{content_id}")

      [%Content{added_to_library_at: ^new_media_added_at} = content]
      when sort == :recently_added ->
        stream_insert(socket, :library, content, at: 0)

      [content] ->
        stream_insert(socket, :library, content, update_only: true)
    end
  end
end
