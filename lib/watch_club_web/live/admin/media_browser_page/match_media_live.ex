defmodule WatchClubWeb.Admin.MediaBrowserPage.MatchMediaLive do
  @moduledoc """
  Match or Rematch a Video by hand. The Instance Administrator searches TMDB by title or by TMDB
  ID, picks a Movie for a Movie file, or a TV Show then its season and episode for a TV Show
  Episode file. Back keeps the search. A Rematch starts with the Current match, which offers to
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
    doc: "a Video, with its `content`'s `implementation` and its `video`'s episode"

  attr :current_user, User, required: true
  attr :on_close, :any, required: true, doc: "a function the dialog calls once it closes"

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        episode_step?: assigns.picked != nil and assigns.picked.identity.type == :tv_show,
        locale: assigns.current_user.settings.locale
      )

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

        <%= if @episode_step? do %>
          <div id={"#{@id}-tv-show"} class="flex items-center gap-group">
            <.search_result_summary result={@picked} type={false} />
          </div>
          <.episode_picker
            id={@id}
            episodes={@episodes}
            season={@season}
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
                aria-label={dgettext("admin_media", "Search TMDB")}
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
            :if={@episode_step?}
            id={"#{@id}-back"}
            variant="secondary"
            phx-click="back"
            phx-target={@myself}
            autofocus={!@episode}
            class="sm:mr-auto"
          >
            <:icon><Lucideicons.arrow_left /></:icon>
            {dgettext("admin_media", "Back")}
          </.button>
          <.button id={"#{@id}-cancel"} variant="secondary" data-modal-close>
            {dgettext("default", "Cancel")}
          </.button>
          <.button
            :if={@media.type == :movie or @episode_step?}
            id={"#{@id}-confirm"}
            disabled={if @episode_step?, do: !@episode, else: !@picked}
            autofocus={@episode_step? and @episode != nil}
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

  # The Content the file has, as a search result, with its episode, and the removal of a Manual
  # Match. The button goes under the title when they don't fit side by side.
  defp current_match(assigns) do
    episode = assigns.media.video.tv_show_episode
    result = SearchResult.from_content(assigns.media.content)

    # Its facts: the year or the episode, and whether it's matched manually
    assigns =
      assign(assigns,
        result: %{result | year: if(!episode, do: result.year), has_media?: false},
        episode: episode
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
        <div class="flex min-w-48 flex-1 items-center gap-group text-base">
          <.search_result_summary result={@result} type={false}>
            <.badge :if={@episode} variant="secondary" size="sm" class="tabular-nums">
              {@episode.formatted_episode_number}
            </.badge>
            <.badge :if={@media.manually_matched?} id={"#{@id}-manual"} variant="muted" size="sm">
              <:icon><Lucideicons.pin /></:icon>
              {dgettext("admin_media", "Matched manually")}
            </.badge>
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
          if @found, do: length(@found.titles) + if(@found.tmdb_id, do: 1, else: 0), else: 0
        }
        on_retry={JS.push("search", value: %{query: @query}, target: @myself)}
        hint={dgettext("admin_media", "Search TMDB by title or TMDB ID.")}
      />
      <section
        :if={@status == :ok and @found.tmdb_id}
        id={"#{@id}-tmdb-id"}
        class="flex flex-col gap-tight"
      >
        <.text_label
          text={dgettext("admin_media", "TMDB ID %{id}", id: @found.tmdb_id)}
          class="px-related"
        />
        <.result_row
          :if={@found.id_result}
          id={"#{@id}-tmdb-id-result"}
          result={@found.id_result}
          picked={@picked}
          myself={@myself}
        />
        <p
          :if={!@found.id_result}
          id={"#{@id}-tmdb-id-not-found"}
          class="flex items-center gap-related p-related text-sm text-text-muted"
        >
          <Lucideicons.search_x class="size-icon-sm shrink-0 text-text-subtle" />
          {if @media.type == :movie,
            do: dgettext("admin_media", "No movie has this TMDB ID."),
            else: dgettext("admin_media", "No TV show has this TMDB ID.")}
        </p>
      </section>
      <section :if={@status == :ok and @found.titles != []} class="flex flex-col gap-tight">
        <.text_label
          :if={@found.tmdb_id}
          text={dgettext("admin_media", "Titles")}
          class="px-related"
        />
        <div class="flex flex-col gap-px">
          <.result_row
            :for={result <- @found.titles}
            id={"#{@id}-result-#{result.identity.external_id}"}
            result={result}
            picked={@picked}
            myself={@myself}
          />
        </div>
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
    assigns = assign(assigns, :selected?, assigns.picked == assigns.result)

    ~H"""
    <button
      id={@id}
      type="button"
      phx-click="pick"
      phx-value-id={@result.identity.external_id}
      phx-target={@myself}
      aria-pressed={@result.identity.type == :movie && to_string(@selected?)}
      class={[
        "flex w-full items-center gap-group rounded-control p-related text-left text-base transition-colors focus-visible:-outline-offset-2",
        @selected? && "bg-surface-selected",
        !@selected? && "hover:bg-surface-hover"
      ]}
    >
      <.search_result_summary result={@result} type={false} />
      <Lucideicons.check :if={@selected?} class="size-icon shrink-0 text-text" />
      <Lucideicons.chevron_right
        :if={@result.identity.type == :tv_show}
        class="size-icon shrink-0 text-text-subtle"
      />
    </button>
    """
  end

  attr :id, :string, required: true
  attr :episodes, AsyncResult, required: true, doc: "the TV Show's episodes, by season"
  attr :season, :integer
  attr :episode, TvShowEpisode
  attr :locale, :atom, required: true
  attr :myself, :any, required: true

  # The seasons as on a TV Show's Episodes, then the season's episodes
  defp episode_picker(assigns) do
    assigns =
      assign(assigns,
        seasons: if(assigns.episodes.ok?, do: assigns.episodes.result, else: [])
      )

    ~H"""
    <div class="flex flex-col gap-group">
      <.search_status
        :if={!@episodes.ok?}
        id={"#{@id}-episodes-status"}
        status={if @episodes.loading, do: :loading, else: :error}
        query=""
        result_count={0}
        on_retry={JS.push("retry_episodes", target: @myself)}
      />
      <.scroll_row :if={length(@seasons) > 1} id={"#{@id}-seasons"} variant="chips">
        <.pill
          :for={{number, _episodes} <- @seasons}
          id={"#{@id}-season-#{number}"}
          current={number == @season}
          phx-click="season"
          phx-value-season={number}
          phx-target={@myself}
        >
          {dgettext("admin_media", "Season %{number}", number: number)}
        </.pill>
      </.scroll_row>
      <span :if={length(@seasons) == 1} class="text-sm font-semibold">
        {dgettext("admin_media", "Season %{number}", number: @season)}
      </span>
      <p :if={@episodes.ok? and @seasons == []} class="p-group text-center text-sm text-text-muted">
        {dgettext("admin_media", "TMDB has no episodes for this TV show yet.")}
      </p>
      <ol :if={@season} id={"#{@id}-episodes"} class="flex flex-col gap-px">
        <li :for={episode <- season_episodes(@seasons, @season)}>
          <button
            id={"#{@id}-episode-#{episode.episode_number}"}
            type="button"
            phx-click="episode"
            phx-value-id={episode.id}
            phx-target={@myself}
            aria-pressed={to_string(episode == @episode)}
            class={[
              "flex min-h-touch-target w-full items-center gap-group rounded-control p-related text-left transition-colors focus-visible:-outline-offset-2",
              episode == @episode && "bg-surface-selected",
              episode != @episode && "hover:bg-surface-hover"
            ]}
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
            <Lucideicons.check :if={episode == @episode} class="size-icon shrink-0 text-text" />
          </button>
        </li>
      </ol>
    </div>
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
       |> assign(
         query: first_query(assigns.media),
         search: nil,
         picked: nil,
         episodes: nil,
         season: nil,
         episode: nil
       )
       |> search()}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket),
    do: {:noreply, socket |> assign(:query, query) |> search()}

  # A Movie is picked; a TV Show opens its seasons
  def handle_event("pick", %{"id" => external_id}, socket) do
    %{titles: titles, id_result: id_result} = socket.assigns.search.result
    picked = Enum.find([id_result | titles], &(&1 && &1.identity.external_id == external_id))

    case picked.identity.type do
      :movie -> {:noreply, assign(socket, :picked, picked)}
      :tv_show -> {:noreply, socket |> assign(picked: picked, episode: nil) |> load_episodes()}
    end
  end

  def handle_event("retry_episodes", _params, socket), do: {:noreply, load_episodes(socket)}

  def handle_event("back", _params, socket),
    do: {:noreply, assign(socket, picked: nil, episodes: nil, season: nil, episode: nil)}

  def handle_event("season", %{"season" => season}, socket),
    do: {:noreply, assign(socket, :season, String.to_integer(season))}

  def handle_event("episode", %{"id" => id}, socket) do
    episode =
      socket.assigns.episodes.result
      |> Enum.flat_map(fn {_season, episodes} -> episodes end)
      |> Enum.find(&(&1.id == id))

    {:noreply, assign(socket, :episode, episode)}
  end

  def handle_event("match", _params, socket) do
    %{media: media, picked: picked, episode: episode, current_user: user} = socket.assigns

    MediaCatalog.match_media!(
      media,
      picked.identity,
      %{
        season_number: episode && episode.season_number,
        episode_number: episode && episode.episode_number
      },
      actor: user
    )

    Flash.send_flash(:info, dgettext("admin_media", "Matched to %{title}.", title: picked.title))
    socket.assigns.on_close.()
    {:noreply, socket}
  end

  def handle_event("remove_manual_match", _params, socket) do
    MediaCatalog.remove_manual_match!(socket.assigns.media, actor: socket.assigns.current_user)

    Flash.send_flash(
      :info,
      dgettext(
        "admin_media",
        "Manual match removed. The next import with All files will match this file again."
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

  def handle_async(:episodes, {:ok, seasons}, socket) do
    {season, episode} = first_episode(seasons, socket.assigns.media)

    {:noreply,
     socket
     |> update(:episodes, &AsyncResult.ok(&1, seasons))
     |> assign(season: season, episode: episode)}
  end

  def handle_async(:episodes, {:exit, {:shutdown, :cancel}}, socket), do: {:noreply, socket}

  def handle_async(:episodes, {:exit, reason}, socket),
    do: {:noreply, update(socket, :episodes, &AsyncResult.failed(&1, {:exit, reason}))}

  # Searches TMDB for the titles of the file's Content Type, and a number as a TMDB ID too
  defp search(socket) do
    %{query: query, media: media, current_user: user} = socket.assigns

    case String.trim(query) do
      "" ->
        socket |> cancel_async(:search) |> assign(:search, nil)

      query ->
        content_type = if media.type == :movie, do: :movies, else: :tv_shows
        tmdb_id = tmdb_id(query)
        otel_context = OpenTelemetry.Ctx.get_current()

        socket
        |> assign(:search, AsyncResult.loading(socket.assigns.search || AsyncResult.loading()))
        |> start_async(:search, fn ->
          OpenTelemetry.Ctx.attach(otel_context)

          %{
            tmdb_id: tmdb_id,
            id_result:
              tmdb_id && Contents.look_up_content!(identity(media, tmdb_id), actor: user),
            titles:
              Contents.search_content!(%{query: query, content_type: content_type}, actor: user).results
          }
        end)
    end
  end

  # Saves the TV Show, as its seasons come from WatchClub
  defp load_episodes(socket) do
    %{picked: picked, current_user: user} = socket.assigns
    otel_context = OpenTelemetry.Ctx.get_current()

    socket
    |> assign(:episodes, AsyncResult.loading())
    |> start_async(:episodes, fn ->
      OpenTelemetry.Ctx.attach(otel_context)
      Contents.get_or_refresh_content!(picked.identity, actor: user)

      picked.identity.external_id
      |> String.to_integer()
      |> Contents.get_episodes_for_show!(load: [:best_localization], actor: user)
      |> Enum.chunk_by(& &1.season_number)
      |> Enum.map(&{hd(&1).season_number, &1})
    end)
  end

  defp status(nil), do: :idle
  defp status(%AsyncResult{loading: loading}) when loading != nil, do: :loading
  defp status(%AsyncResult{failed: failed}) when failed != nil, do: :error
  defp status(%AsyncResult{ok?: true}), do: :ok

  defp tmdb_id(query) do
    case Integer.parse(query) do
      {id, ""} when id > 0 -> id
      _other -> nil
    end
  end

  defp identity(%Media{type: :movie}, tmdb_id), do: ContentIdentity.for_movie(tmdb_id)
  defp identity(%Media{type: :tv_show_episode}, tmdb_id), do: ContentIdentity.for_tv_show(tmdb_id)

  defp search_placeholder(:movie), do: dgettext("admin_media", "Movie title or TMDB ID")

  defp search_placeholder(:tv_show_episode),
    do: dgettext("admin_media", "TV show title or TMDB ID")

  # The current title, or the one in the file name
  defp first_query(%Media{content: %Content{} = content}), do: content_title(content)

  defp first_query(%Media{type: :tv_show_episode, path: path}),
    do: FilenameParser.parse_episode(path)[:tv_show_title] || file_title(path)

  defp first_query(%Media{path: path}), do: file_title(path)

  defp file_title(path), do: elem(FilenameParser.title_and_year(path), 0) || Path.basename(path)

  # The current episode when rematching within its TV Show, else the file name's, in a season the
  # TV Show has. Else its first season, with no episode.
  defp first_episode([], _media), do: {nil, nil}

  defp first_episode([{first_season, _episodes} | _seasons] = seasons, media) do
    all_episodes = Enum.flat_map(seasons, fn {_season, episodes} -> episodes end)
    current = media.video.tv_show_episode
    file = FilenameParser.parse_episode(media.path)

    episode =
      Enum.find(all_episodes, &(current && &1.id == current.id)) ||
        Enum.find(
          all_episodes,
          &(&1.season_number == file[:season_number] and
              &1.episode_number == file[:episode_number])
        )

    if episode, do: {episode.season_number, episode}, else: {first_season, nil}
  end

  defp season_episodes(seasons, season),
    do: seasons |> List.keyfind(season, 0, {season, []}) |> elem(1)
end
