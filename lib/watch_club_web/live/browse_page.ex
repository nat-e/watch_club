defmodule WatchClubWeb.BrowsePage do
  @moduledoc """
  Browse: the Library's posters of one Content Type, Movies first, with a row of filters and a
  sort menu. The type, filters and sort live in the URL, so Back undoes them.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.ContentTypeIcon
  import WatchClubWeb.Components.Contents.PosterCard

  alias WatchClub.Contents.{Content, Genre, LibrarySort}
  alias WatchClub.Conversations.Participant
  alias WatchClub.History.WatchProgress
  alias WatchClub.Languages
  alias WatchClub.MediaCatalog.Media
  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive
  alias WatchClubWeb.Helpers.KeysetStreamState

  @page_size 40
  # Pages leave out `added_to_library_at`: with the Title sort, it empties the next page (WC-51)
  @content_fields [
    :title,
    :poster_path,
    :actor_progress_status,
    :incomplete?,
    actor_recommendations: [:recommended_by]
  ]
  @default_type :movie
  # What Clear filters resets. The type isn't a filter: Browse always shows one.
  @no_filters %{
    not_watched?: false,
    recommended?: false,
    genres: [],
    decades: [],
    original_languages: [],
    min_rating: nil
  }
  # The filters in More, which its button counts
  @more_filters [:genres, :decades, :original_languages, :min_rating]
  # More's Rating choices besides Any, which keep the Content rated at least this
  @min_ratings [6, 7, 8]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      playback_session={@playback_session}
      title={dgettext("nav", "Browse")}
      search
      class="@container pt-group!"
    >
      <div class="flex min-w-0 items-center gap-related">
        <.scroll_row id="filters" variant="chips" class="min-w-0 flex-1">
          <div
            id="filter-types"
            role="radiogroup"
            aria-label={dgettext("browse", "Type")}
            class="flex shrink-0 items-center gap-related"
          >
            <.filter_chip
              :for={type <- ContentType.library_display_order()}
              id={"filter-type-#{type}"}
              on={@type == type}
              radio
              phx-click="change_type"
              phx-value-type={type}
            >
              <:icon><.content_type_icon type={type} /></:icon>
              {ContentType.translated_plural_label(type)}
            </.filter_chip>
          </div>
          <.divider />
          <%!-- Hidden rather than removed, so the chips after it keep their focus --%>
          <div
            id="filters-clear"
            class={["flex shrink-0 items-center gap-related", not filtered?(@filters) && "hidden"]}
          >
            <.button
              id="filters-clear-button"
              variant="secondary"
              size="icon-sm"
              phx-click={clear_filters()}
              aria-label={dgettext("browse", "Clear filters")}
              class="rounded-full!"
            >
              <Lucideicons.x />
            </.button>
            <.divider />
          </div>
          <.filter_chip
            id="filter-not-watched"
            on={@filters.not_watched?}
            phx-click="change_filter"
            phx-value-filter="not_watched"
          >
            <:icon><Lucideicons.eye_off /></:icon>
            {dgettext("browse", "Not watched")}
          </.filter_chip>
          <.filter_chip
            id="filter-recommended"
            on={@filters.recommended?}
            phx-click="change_filter"
            phx-value-filter="recommended"
          >
            <:icon><Lucideicons.user_round_check /></:icon>
            {dgettext("browse", "Recommended to me")}
          </.filter_chip>
          <.divider />
          <.more_button filters={@filters} />
        </.scroll_row>
        <.sort_menu type={@type} filters={@filters} sort={@sort} />
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
            <.button id="library-clear-filters" variant="secondary" phx-click={clear_filters()}>
              {dgettext("browse", "Clear filters")}
            </.button>
          </.empty>
          <.empty :if={not filtered?(@filters)}>
            <:icon><.content_type_icon type={@type} /></:icon>
            <:title>{empty_title(@type)}</:title>
            <:description>
              {dgettext("browse", "They show up here once they're on the server.")}
            </:description>
          </.empty>
        </li>
        <li :for={{dom_id, content} <- @streams.library} id={dom_id}>
          <.poster_card content={content} locale={@current_user.settings.locale}>
            <:action>
              <.live_component
                id={PlayOrRequestButtonLive.dom_id(ContentIdentity.from_content(content))}
                module={PlayOrRequestButtonLive}
                content_identity={ContentIdentity.from_content(content)}
                current_user={@current_user}
                variant="poster"
              />
            </:action>
          </.poster_card>
        </li>
      </ul>

      <.infinite_scroll_trigger
        :if={KeysetStreamState.can_load_more?(@stream_state)}
        id="library-load-more"
        event="load_more"
      />

      <.more_filters :if={@filter_options} filters={@filters} options={@filter_options} />
    </Layouts.app>
    """
  end

  defp empty_title(:movie), do: dgettext("browse", "No movies yet")
  defp empty_title(:tv_show), do: dgettext("browse", "No TV shows yet")
  defp empty_title(:sports_event), do: dgettext("browse", "No sports events yet")

  # Between the type chips, Not watched and More
  defp divider(assigns) do
    ~H"""
    <span class="h-6 w-px shrink-0 bg-border" aria-hidden="true"></span>
    """
  end

  attr :filters, :map, required: true

  # Opens the genres, decades, original languages and rating, with how many of them are on
  defp more_button(assigns) do
    assigns =
      assign(
        assigns,
        :count,
        Enum.count(@more_filters, &(assigns.filters[&1] != @no_filters[&1]))
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

  attr :type, :atom, required: true, doc: "a `ContentType`"
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
        patch={browse_path(@type, @filters, sort)}
        checked={@sort == sort}
      >
        {LibrarySort.translated_label(sort)}
      </.dropdown_menu_item>
    </.dropdown_menu>
    """
  end

  attr :filters, :map, required: true

  attr :options, :map,
    required: true,
    doc: "the Library's genres, decades and original languages"

  # From the bottom of the screen on phones. Each choice applies at once, and a list without
  # choices is left out.
  defp more_filters(assigns) do
    assigns = assign(assigns, :min_ratings, @min_ratings)

    ~H"""
    <.modal id="more-filters" size="md" phone="sheet" on_close={JS.push("close_more_filters")}>
      <:title>{dgettext("browse", "Filters")}</:title>
      <fieldset :if={@options.genres != []} class="flex min-w-0 flex-col gap-related">
        <legend class="mb-related"><.text_label text={dgettext("browse", "Genre")} /></legend>
        <div class="flex flex-wrap gap-related">
          <.filter_chip
            :for={genre <- @options.genres}
            id={"filter-genre-#{genre}"}
            on={genre in @filters.genres}
            phx-click="change_filter"
            phx-value-filter="genre"
            phx-value-choice={genre}
          >
            {Genre.translated_label(genre)}
          </.filter_chip>
        </div>
      </fieldset>
      <fieldset :if={@options.decades != []} class="flex min-w-0 flex-col gap-related">
        <legend class="mb-related"><.text_label text={dgettext("browse", "Year")} /></legend>
        <div class="flex flex-wrap gap-related">
          <.filter_chip
            :for={decade <- @options.decades}
            id={"filter-decade-#{decade}"}
            on={decade in @filters.decades}
            phx-click="change_filter"
            phx-value-filter="decade"
            phx-value-choice={decade}
            class="tabular-nums"
          >
            {dgettext("browse", "%{decade}s", decade: decade)}
          </.filter_chip>
        </div>
      </fieldset>
      <fieldset role="radiogroup" class="flex min-w-0 flex-col gap-related">
        <legend class="mb-related"><.text_label text={dgettext("browse", "Rating")} /></legend>
        <div class="flex flex-wrap gap-related">
          <.filter_chip
            id="filter-rating-any"
            on={@filters.min_rating == nil}
            radio
            phx-click="change_filter"
            phx-value-filter="rating"
          >
            {dpgettext("browse", "rating", "Any")}
          </.filter_chip>
          <.filter_chip
            :for={min_rating <- @min_ratings}
            id={"filter-rating-#{min_rating}"}
            on={@filters.min_rating == min_rating}
            radio
            phx-click="change_filter"
            phx-value-filter="rating"
            phx-value-choice={min_rating}
          >
            <:icon><Lucideicons.star class="fill-current text-warning" /></:icon>
            {dgettext("browse", "%{rating}+", rating: min_rating)}
          </.filter_chip>
        </div>
      </fieldset>
      <fieldset :if={@options.original_languages != []} class="flex min-w-0 flex-col">
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
            phx-click="change_filter"
            phx-value-filter="language"
            phx-value-choice={language}
          />
          <span class="text-base leading-none" aria-hidden="true">
            {Languages.to_flag(language)}
          </span>
          <span class="min-w-0 truncate">{Languages.to_name(language)}</span>
        </label>
      </fieldset>
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     # More's genres, decades and original languages while it's open, as they were when it opened
     |> assign(:filter_options, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     # An unknown type shows Movies
     |> assign(
       :type,
       Url.parse_url_param(params["type"], ContentType.library_display_order(), @default_type)
     )
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

  def handle_event("change_type", %{"type" => type}, socket) do
    %{filters: filters, sort: sort} = socket.assigns
    type = Url.parse_url_param(type, ContentType.library_display_order(), @default_type)
    {:noreply, push_patch(socket, to: browse_path(type, filters, sort))}
  end

  # Changes the filters from the server's own state, so quick taps all count
  def handle_event("change_filter", %{"filter" => filter} = params, socket) do
    %{type: type, filters: filters, sort: sort} = socket.assigns
    filters = change_filter(filters, filter, params["choice"])
    {:noreply, push_patch(socket, to: browse_path(type, filters, sort))}
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

      # Someone may have recommended it to the User
      %{resource: Participant, action: %{name: :create}, metadata: %{content_id: id}} ->
        {:noreply, update_poster!(socket, id)}

      _other ->
        {:noreply, socket}
    end
  end

  # The filters in the URL. Unknown genres and ratings, and decades that aren't numbers, are left
  # out.
  defp filters(params) do
    %{
      not_watched?: params["not_watched"] == "true",
      recommended?: params["recommended"] == "true",
      genres:
        for({:ok, genre} <- Enum.map(list_param(params["genres"]), &Genre.match/1), do: genre),
      decades:
        for({decade, ""} <- Enum.map(list_param(params["decades"]), &Integer.parse/1), do: decade),
      original_languages: list_param(params["languages"]),
      min_rating: Url.parse_url_param(params["rating"], @min_ratings)
    }
  end

  defp list_param(values) when is_binary(values), do: String.split(values, ",", trim: true)
  # Missing, or a list from a hand-edited URL such as `decades[]=1990`
  defp list_param(_values), do: []

  # A rating replaces the one that's on. The other choices turn on or off.
  defp change_filter(_filters, "clear", _choice), do: @no_filters

  defp change_filter(filters, "rating", min_rating),
    do: %{filters | min_rating: Url.parse_url_param(min_rating, @min_ratings)}

  defp change_filter(filters, "not_watched", _choice),
    do: %{filters | not_watched?: not filters.not_watched?}

  defp change_filter(filters, "recommended", _choice),
    do: %{filters | recommended?: not filters.recommended?}

  defp change_filter(filters, "genre", genre) do
    {:ok, genre} = Genre.match(genre)
    %{filters | genres: toggle_choice(filters.genres, genre)}
  end

  defp change_filter(filters, "decade", decade),
    do: %{filters | decades: toggle_choice(filters.decades, String.to_integer(decade))}

  defp change_filter(filters, "language", language),
    do: %{filters | original_languages: toggle_choice(filters.original_languages, language)}

  defp toggle_choice(choices, choice) do
    if choice in choices, do: List.delete(choices, choice), else: choices ++ [choice]
  end

  # Browse's URL with this type, filters and sort, without the defaults
  defp browse_path(type, filters, sort) do
    params =
      Enum.reject(
        [
          type: type != @default_type && type,
          not_watched: filters.not_watched?,
          recommended: filters.recommended?,
          genres: Enum.join(filters.genres, ","),
          decades: Enum.join(filters.decades, ","),
          languages: Enum.join(filters.original_languages, ","),
          rating: filters.min_rating,
          sort: sort != LibrarySort.default() && sort
        ],
        fn {_param, value} -> value in [nil, false, ""] end
      )

    ~p"/browse?#{params}"
  end

  # Keeps the type and the sort, and moves focus to the first filter, as the clear buttons hide
  defp clear_filters do
    "change_filter"
    |> JS.push(value: %{filter: "clear"})
    |> JS.focus(to: "#filter-not-watched")
  end

  defp filtered?(filters), do: filters != @no_filters

  defp load_page!(socket) do
    %{stream_state: stream_state, type: type, filters: filters, sort: sort, current_user: user} =
      socket.assigns

    {:ok, new_state, contents} =
      KeysetStreamState.load_page(stream_state, fn page_options ->
        Contents.get_contents_in_library(Map.merge(filters, %{type: type, sort: sort}),
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
    %{type: type, filters: filters, sort: sort, current_user: user} = socket.assigns

    case Contents.get_contents_in_library!(Map.put(filters, :type, type),
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
