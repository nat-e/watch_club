defmodule WatchClubWeb.Admin.MediaBrowserPage.MatchMediaLive do
  @moduledoc """
  Match or Rematch a Video by hand. The Instance Administrator searches the Metadata Provider of
  the file's Media Type by title or by ID: TMDB for a Movie, or for a TV Show then its season and
  episode; sportarr.net for a Sports Event. Back keeps the search. A Rematch starts with the Current match, which offers to
  remove a Manual Match.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Admin.MediaBrowserPage.MediaPoster, only: [content_title: 1]
  import WatchClubWeb.Components.Search.SearchResultRow, only: [search_result_summary: 1]
  import WatchClubWeb.Components.Search.SearchStatus

  alias Phoenix.LiveView.AsyncResult
  alias WatchClub.Contents.SearchResult
  alias WatchClub.MediaSources.Import.Scanner.Filesystem.Identify.FilenameParser
  alias WatchClubWeb.Hooks.Flash

  attr :id, :string, required: true

  attr :media, Media,
    required: true,
    doc: "a Video, with its `content`'s `title` and `poster_path`, and its `video`'s episode"

  attr :current_user, User, required: true
  attr :on_close, :any, required: true, doc: "a function the dialog calls once it closes"

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :locale, assigns.current_user.settings.locale)

    ~H"""
    <div>
      <.modal
        id={@id}
        size="md"
        phone="full_screen"
        on_close={JS.push("close", target: @myself)}
        class="w-full sm:h-[min(44rem,85svh)]"
      >
        <:title>
          {if @media.content,
            do: dgettext("admin_media", "Rematch"),
            else: dgettext("admin_media", "Match")}
        </:title>
        <:description>
          <span class="break-all">{Path.basename(@media.path)}</span>
        </:description>

        <%= if @tv_show do %>
          <div id={"#{@id}-tv-show"} class="flex items-center gap-group p-related text-base">
            <.search_result_summary result={@picked} type={false} />
          </div>
          <.episode_picker
            id={@id}
            tv_show={@tv_show}
            season={@season}
            episodes={@episodes}
            episode={@episode}
            locale={@locale}
            myself={@myself}
          />
        <% else %>
          <.current_match :if={@media.content} id={@id} media={@media} myself={@myself} />
          <.form
            id={"#{@id}-search"}
            for={to_form(%{})}
            layout="none"
            role="search"
            autocomplete="off"
            phx-change="search"
            phx-submit="search"
            phx-target={@myself}
            class="sticky top-0 z-10 bg-surface-overlay"
          >
            <div class="relative">
              <Lucideicons.search
                aria-hidden="true"
                class="pointer-events-none absolute top-1/2 left-3 size-icon-sm -translate-y-1/2 text-text-subtle"
              />
              <.input
                id={"#{@id}-query"}
                name="query"
                value={@query}
                type="search"
                placeholder={search_placeholder(@media.type)}
                aria-label={search_label(@media.type)}
                autofocus
                phx-debounce="300"
                class="pl-9!"
              />
            </div>
          </.form>
          <.search_results
            id={@id}
            search={@search}
            query={@query}
            media={@media}
            picked={@picked}
            myself={@myself}
          />
        <% end %>

        <:footer class="mt-auto">
          <.button
            :if={@tv_show}
            id={"#{@id}-back"}
            variant="secondary"
            phx-click="back"
            phx-target={@myself}
            phx-mounted={JS.focus()}
            class="sm:mr-auto"
          >
            <:icon><Lucideicons.arrow_left /></:icon>
            {dgettext("admin_media", "Back")}
          </.button>
          <.button id={"#{@id}-cancel"} variant="secondary" data-modal-close>
            {dgettext("default", "Cancel")}
          </.button>
          <.button
            :if={@media.type != :tv_show_episode or @tv_show}
            id={"#{@id}-confirm"}
            disabled={if @tv_show, do: !@episode, else: !@picked}
            phx-click="match"
            phx-target={@myself}
          >
            {dgettext("admin_media", "Match")}
          </.button>
        </:footer>
      </.modal>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :media, Media, required: true
  attr :myself, :any, required: true

  # The Content the file has, with its year or episode, and the removal of a Manual Match. The
  # button goes under the title when they don't fit side by side.
  defp current_match(assigns) do
    content = assigns.media.content

    assigns =
      assign(assigns,
        result: %SearchResult{
          identity: ContentIdentity.from_content(content),
          title: content.title,
          year: content.release_date && content.release_date.year,
          poster_path: content.poster_path
        },
        episode: Enum.find_value(assigns.media.video.parts, & &1.tv_show_episode)
      )

    ~H"""
    <section
      id={"#{@id}-current"}
      aria-labelledby={"#{@id}-current-label"}
      class="flex flex-col gap-tight"
    >
      <.text_label
        id={"#{@id}-current-label"}
        text={dgettext("admin_media", "Current match")}
        class="px-related"
      />
      <div class="flex flex-wrap items-center gap-x-group gap-y-related p-related">
        <div class="flex min-w-60 flex-1 items-center gap-group text-base">
          <.search_result_summary result={@result}>
            <:facts>
              <span :if={!@episode}>{@result.year}</span>
              <.badge :if={@episode} variant="secondary" size="sm" class="tabular-nums">
                {@episode.formatted_episode_number}
              </.badge>
              <.badge :if={@media.manually_matched?} id={"#{@id}-manual"} variant="muted" size="sm">
                <:icon><Lucideicons.pin /></:icon>
                {dgettext("admin_media", "Matched manually")}
              </.badge>
            </:facts>
          </.search_result_summary>
        </div>
        <.button
          :if={@media.manually_matched?}
          id={"#{@id}-remove-manual-match"}
          variant="secondary"
          size="sm"
          phx-click="remove_manual_match"
          phx-target={@myself}
          class="pointer-coarse:min-h-touch-target"
        >
          {dgettext("admin_media", "Remove manual match")}
        </.button>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :search, AsyncResult, doc: "nil before typing"
  attr :query, :string, required: true
  attr :media, Media, required: true
  attr :picked, SearchResult
  attr :myself, :any, required: true

  # The title with the typed TMDB ID first, labeled, then the titles TMDB finds
  defp search_results(assigns) do
    assigns =
      assign(assigns,
        status: status(assigns.search),
        found: assigns.search && assigns.search.result
      )

    ~H"""
    <div class="flex flex-col gap-group">
      <.search_status
        id={"#{@id}-status"}
        status={@status}
        query={@query}
        result_count={
          if @found, do: length(@found.titles) + if(@found.typed_id, do: 1, else: 0), else: 0
        }
        on_retry={JS.push("search", value: %{query: @query}, target: @myself)}
        hint={search_hint(@media.type)}
      />
      <section
        :if={@status == :ok and @found.typed_id}
        id={"#{@id}-typed-id"}
        class="flex flex-col gap-tight"
      >
        <.text_label
          text={typed_id_label(@found.typed_id)}
          class="px-related"
        />
        <.result_row
          :if={@found.id_result}
          id={"#{@id}-typed-id-result"}
          result={@found.id_result}
          picked={@picked}
          myself={@myself}
        />
        <p
          :if={!@found.id_result}
          id={"#{@id}-typed-id-not-found"}
          class="flex items-center gap-related p-related text-sm text-text-muted"
        >
          <Lucideicons.search_x class="size-icon-sm shrink-0 text-text-subtle" />
          {typed_id_not_found(@media.type)}
        </p>
      </section>
      <section :if={@status == :ok and @found.titles != []} class="flex flex-col gap-tight">
        <.text_label
          :if={@found.typed_id}
          text={dgettext("admin_media", "Titles")}
          class="px-related"
        />
        <ul class="flex flex-col gap-px">
          <li :for={result <- @found.titles}>
            <.result_row
              id={"#{@id}-result-#{result.identity.external_id}"}
              result={result}
              picked={@picked}
              myself={@myself}
            />
          </li>
        </ul>
      </section>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :result, SearchResult, required: true
  attr :picked, SearchResult
  attr :myself, :any, required: true

  # A Movie is picked, then matched. A TV Show opens its seasons.
  defp result_row(assigns) do
    ~H"""
    <.option_row
      id={@id}
      selected={if @result.identity.type != :tv_show, do: @result == @picked}
      phx-click="pick"
      phx-value-id={@result.identity.external_id}
      phx-target={@myself}
      class="text-base"
    >
      <.search_result_summary result={@result} type={false} />
    </.option_row>
    """
  end

  attr :id, :string, required: true
  attr :tv_show, AsyncResult, required: true, doc: "the TV Show's Content and season numbers"
  attr :season, :integer
  attr :episodes, :list, required: true, doc: "the season's"
  attr :episode, TvShowEpisode
  attr :locale, :atom, required: true
  attr :myself, :any, required: true

  # The seasons as on a TV Show's Episodes, then the season's episodes
  defp episode_picker(assigns) do
    assigns =
      assign(assigns,
        season_numbers:
          if(assigns.tv_show.ok?, do: assigns.tv_show.result.season_numbers, else: [])
      )

    ~H"""
    <div class="flex flex-col gap-group">
      <div :if={@tv_show.loading} class="flex flex-col" aria-hidden="true">
        <div :for={_row <- 1..5} class="flex animate-pulse flex-col gap-related p-related">
          <span class="h-3 w-1/2 rounded-full bg-surface-hover"></span>
          <span class="h-3 w-1/4 rounded-full bg-surface-hover"></span>
        </div>
      </div>
      <.empty :if={@tv_show.failed} id={"#{@id}-episodes-error"} border={false} size="sm">
        <:icon><Lucideicons.triangle_alert /></:icon>
        <:description>{dgettext("admin_media", "Couldn't load the episodes.")}</:description>
        <.button
          id={"#{@id}-episodes-retry"}
          variant="secondary"
          size="sm"
          phx-click="retry_tv_show"
          phx-target={@myself}
        >
          {dgettext("admin_media", "Try again")}
        </.button>
      </.empty>
      <.scroll_row :if={length(@season_numbers) > 1} id={"#{@id}-seasons"} variant="chips">
        <.pill
          :for={number <- @season_numbers}
          id={"#{@id}-season-#{number}"}
          current={number == @season}
          phx-click="season"
          phx-value-season={number}
          phx-target={@myself}
        >
          {dgettext("admin_media", "Season %{number}", number: number)}
        </.pill>
      </.scroll_row>
      <span :if={length(@season_numbers) == 1} class="text-sm font-semibold">
        {dgettext("admin_media", "Season %{number}", number: @season)}
      </span>
      <p
        :if={@tv_show.ok? and @season_numbers == []}
        class="p-group text-center text-sm text-text-muted"
      >
        {dgettext("admin_media", "TMDB has no episodes for this TV show yet.")}
      </p>
      <ol :if={@episodes != []} id={"#{@id}-episodes"} class="flex flex-col gap-px">
        <li :for={episode <- @episodes}>
          <.option_row
            id={"#{@id}-episode-#{episode.episode_number}"}
            selected={episode == @episode}
            phx-click="episode"
            phx-value-id={episode.id}
            phx-target={@myself}
            phx-mounted={episode == @episode && JS.focus()}
            class="min-h-touch-target"
          >
            <span class="flex min-w-0 flex-1 flex-col gap-tight">
              <span class="truncate text-base text-text">
                <span class="font-semibold">{episode.formatted_episode_number}</span>
                <span :if={episode.best_localization}>· {episode.best_localization.title}</span>
              </span>
              <span :if={episode.air_date} class="text-xs text-text-muted">
                {Time.long_date(episode.air_date, @locale)}
              </span>
            </span>
          </.option_row>
        </li>
      </ol>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :selected, :boolean, doc: "whether it's picked; nil for a row that opens the next step"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  # A row to pick, with a check once picked, or a row that opens the next step, with an arrow
  defp option_row(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      aria-pressed={@selected != nil && to_string(@selected)}
      class={[
        "flex w-full items-center gap-group rounded-control p-related text-left transition-colors focus-visible:-outline-offset-2",
        @selected && "bg-surface-selected",
        !@selected && "hover:bg-surface-hover",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
      <Lucideicons.check :if={@selected} class="size-icon shrink-0 text-text" />
      <Lucideicons.chevron_right :if={@selected == nil} class="size-icon shrink-0 text-text-subtle" />
    </button>
    """
  end

  # No need to support update_many for a modal
  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if Map.has_key?(socket.assigns, :query) do
      {:ok, socket}
    else
      {:ok,
       socket
       |> assign(query: first_query(assigns.media), search: nil, picked: nil)
       |> assign(tv_show: nil, season: nil, episodes: [], episode: nil)
       |> search()}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket),
    do: {:noreply, socket |> assign(query: query, picked: nil) |> search()}

  # A Movie or a Sports Event is picked; a TV Show opens its seasons
  def handle_event("pick", %{"id" => external_id}, socket) do
    %{titles: titles, id_result: id_result} = socket.assigns.search.result
    picked = Enum.find([id_result | titles], &(&1 && &1.identity.external_id == external_id))
    socket = assign(socket, :picked, picked)

    if picked.identity.type == :tv_show,
      do: {:noreply, load_tv_show(socket)},
      else: {:noreply, socket}
  end

  def handle_event("retry_tv_show", _params, socket), do: {:noreply, load_tv_show(socket)}

  def handle_event("back", _params, socket) do
    {:noreply,
     socket
     |> cancel_async(:tv_show)
     |> assign(picked: nil, tv_show: nil, season: nil, episodes: [], episode: nil)}
  end

  def handle_event("season", %{"season" => season}, socket) do
    %{tv_show: %{result: %{content: content}}, current_user: user} = socket.assigns
    season = String.to_integer(season)

    {:noreply,
     assign(socket,
       season: season,
       episodes: season_episodes!(content, season, user),
       episode: nil
     )}
  end

  def handle_event("episode", %{"id" => id}, socket),
    do: {:noreply, assign(socket, :episode, Enum.find(socket.assigns.episodes, &(&1.id == id)))}

  def handle_event("match", _params, socket) do
    %{media: media, picked: picked, episode: episode, current_user: user} = socket.assigns

    episode_numbers = %{
      season_number: episode && episode.season_number,
      episode_number: episode && episode.episode_number
    }

    case MediaCatalog.match_media(media, picked.identity, episode_numbers, actor: user) do
      {:ok, _media} ->
        Flash.send_flash(
          :info,
          dgettext("admin_media", "Matched to %{title}.", title: picked.title)
        )

        socket.assigns.on_close.()
        {:noreply, socket}

      # TMDB can fail to give a missing Movie
      {:error, _error} ->
        Flash.send_flash(:error, dgettext("admin_media", "Couldn't match the file. Try again."))
        {:noreply, socket}
    end
  end

  def handle_event("remove_manual_match", _params, socket) do
    MediaCatalog.unmatch_media!(socket.assigns.media, actor: socket.assigns.current_user)

    Flash.send_flash(
      :info,
      dgettext(
        "admin_media",
        "Manual match removed. The file is unmatched until an import matches it."
      )
    )

    socket.assigns.on_close.()
    {:noreply, socket}
  end

  def handle_event("close", _params, socket) do
    socket.assigns.on_close.()
    {:noreply, socket}
  end

  @impl true
  def handle_async(:search, {:ok, found}, socket),
    do: {:noreply, update(socket, :search, &AsyncResult.ok(&1, found))}

  def handle_async(:search, {:exit, {:shutdown, :cancel}}, socket), do: {:noreply, socket}

  def handle_async(:search, {:exit, reason}, socket),
    do: {:noreply, update(socket, :search, &AsyncResult.failed(&1, {:exit, reason}))}

  def handle_async(:tv_show, {:ok, tv_show}, socket) do
    %{content: content, season_numbers: season_numbers, season: season, episodes: episodes} =
      tv_show

    {:noreply,
     assign(socket,
       tv_show:
         AsyncResult.ok(socket.assigns.tv_show, %{
           content: content,
           season_numbers: season_numbers
         }),
       season: season,
       episodes: episodes,
       episode: Enum.find(episodes, &(&1.episode_number == tv_show.episode_number))
     )}
  end

  def handle_async(:tv_show, {:exit, {:shutdown, :cancel}}, socket), do: {:noreply, socket}

  def handle_async(:tv_show, {:exit, reason}, socket),
    do: {:noreply, update(socket, :tv_show, &AsyncResult.failed(&1, {:exit, reason}))}

  # Searches TMDB for the titles of the file's Content Type, and a number as a TMDB ID too
  defp search(socket) do
    %{query: query, media: media, current_user: user} = socket.assigns

    case String.trim(query) do
      "" ->
        socket |> cancel_async(:search) |> assign(:search, nil)

      query ->
        typed_id = typed_id(media.type, query)
        otel_context = OpenTelemetry.Ctx.get_current()

        socket
        |> assign(:search, AsyncResult.loading(socket.assigns.search || AsyncResult.loading()))
        |> start_async(:search, fn ->
          OpenTelemetry.Ctx.attach(otel_context)

          %{
            typed_id: typed_id,
            id_result: typed_id && Contents.look_up_content!(typed_id, actor: user),
            titles: Contents.search_content!(search_input(media.type, query), actor: user).results
          }
        end)
    end
  end

  # Saves the TV Show, whose seasons come from WatchClub, and opens the file's season
  defp load_tv_show(socket) do
    %{picked: picked, media: media, current_user: user} = socket.assigns
    otel_context = OpenTelemetry.Ctx.get_current()

    socket
    |> assign(tv_show: AsyncResult.loading(), season: nil, episodes: [], episode: nil)
    |> start_async(:tv_show, fn ->
      OpenTelemetry.Ctx.attach(otel_context)

      content =
        Contents.get_or_refresh_content!(picked.identity,
          load: [implementation: %{load: [tv_show: :season_numbers]}],
          actor: user
        )

      season_numbers = content.implementation.season_numbers
      {season, episode_number} = first_episode(season_numbers, content, media)

      %{
        content: content,
        season_numbers: season_numbers,
        season: season,
        # Intentionally small: one season
        episodes: if(season, do: season_episodes!(content, season, user), else: []),
        episode_number: episode_number
      }
    end)
  end

  defp season_episodes!(content, season, user) do
    content.external_id
    |> String.to_integer()
    |> Contents.get_episodes_for_show!(
      query: [filter: [season_number: season]],
      load: [:best_localization],
      actor: user
    )
  end

  defp status(nil), do: :idle
  defp status(%AsyncResult{loading: loading}) when loading != nil, do: :loading
  defp status(%AsyncResult{failed: failed}) when failed != nil, do: :error
  defp status(%AsyncResult{ok?: true}), do: :ok

  # The titles a file of this Media Type can match
  defp search_input(:movie, query), do: %{query: query, type: :movie}
  defp search_input(:tv_show_episode, query), do: %{query: query, type: :tv_show}
  defp search_input(:sports_event, query), do: %{query: query, content_type: :sports_events}

  # The Content of a typed TMDB ID, or of a Sportarr ID such as ev-028133
  defp typed_id(:sports_event, query) do
    if Regex.match?(~r/^ev-\d+$/i, query),
      do: ContentIdentity.for_sports_event(String.downcase(query))
  end

  defp typed_id(media_type, query) do
    case {media_type, Integer.parse(query)} do
      {:movie, {id, ""}} when id > 0 -> ContentIdentity.for_movie(id)
      {:tv_show_episode, {id, ""}} when id > 0 -> ContentIdentity.for_tv_show(id)
      _other -> nil
    end
  end

  defp typed_id_label(%ContentIdentity{external_id_source: :tmdb, external_id: id}),
    do: dgettext("admin_media", "TMDB ID %{id}", id: id)

  defp typed_id_label(%ContentIdentity{external_id_source: :sportarr, external_id: id}),
    do: dgettext("admin_media", "Sportarr ID %{id}", id: id)

  defp typed_id_not_found(:movie), do: dgettext("admin_media", "No movie has this TMDB ID.")

  defp typed_id_not_found(:tv_show_episode),
    do: dgettext("admin_media", "No TV show has this TMDB ID.")

  defp typed_id_not_found(:sports_event),
    do: dgettext("admin_media", "No event has this Sportarr ID.")

  defp search_placeholder(:movie), do: dgettext("admin_media", "Movie title or TMDB ID")

  defp search_placeholder(:tv_show_episode),
    do: dgettext("admin_media", "TV show title or TMDB ID")

  defp search_placeholder(:sports_event),
    do: dgettext("admin_media", "Event title or Sportarr ID")

  defp search_label(:sports_event), do: dgettext("admin_media", "Search sportarr.net")
  defp search_label(_tmdb_media_type), do: dgettext("admin_media", "Search TMDB")

  defp search_hint(:sports_event),
    do: dgettext("admin_media", "Search sportarr.net by title or Sportarr ID.")

  defp search_hint(_tmdb_media_type),
    do: dgettext("admin_media", "Search TMDB by title or TMDB ID.")

  # The current title, or the one in the file name
  defp first_query(%Media{content: %Content{} = content}), do: content_title(content)

  defp first_query(%Media{type: :tv_show_episode, path: path}),
    do: FilenameParser.parse_episode(path)[:tv_show_title] || file_title(path)

  defp first_query(%Media{path: path}), do: file_title(path)

  defp file_title(path), do: elem(FilenameParser.title_and_year(path), 0) || Path.basename(path)

  # The current episode when rematching within its TV Show, else the file name's, in a season the
  # TV Show has. Else its first season, with no episode.
  defp first_episode([], _content, _media), do: {nil, nil}

  defp first_episode([first_season | _seasons] = season_numbers, content, media) do
    position =
      case {media.content, Enum.find_value(media.video.parts, & &1.tv_show_episode)} do
        {%Content{id: id}, %TvShowEpisode{} = episode} when id == content.id ->
          {episode.season_number, episode.episode_number}

        _other ->
          file = FilenameParser.parse_episode(media.path)
          {file[:season_number], file[:episode_number]}
      end

    case position do
      {season, episode} when is_integer(season) ->
        if season in season_numbers, do: {season, episode}, else: {first_season, nil}

      _none ->
        {first_season, nil}
    end
  end
end
