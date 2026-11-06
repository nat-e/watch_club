defmodule WatchClubWeb.Contents.ContentPage do
  @moduledoc """
  The page of a Movie or a TV Show: what it is, from TMDB, how far the User got, with Play or
  Resume, every TV Show Episode in a modal, and the other Users who watched it.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.TmdbBackdrop
  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.Rating
  alias WatchClub.Integrations.Tmdb.{MovieDetailsResponse, TvDetailsResponse}
  alias WatchClub.Languages
  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive
  alias WatchClubWeb.Contents.ContentPage.EpisodesModalLive

  # The User's Watch Progress, for the actions under the overview
  @content_load [
    :has_media?,
    :actor_progress_status,
    implementation: %{
      load: [
        movie: [:actor_progress],
        tv_show: [:actor_percent_watched, actor_next_episode: [:actor_progress_status]]
      ]
    }
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      title={title(@details)}
      content_page?
    >
      <article aria-labelledby="content-title" class="@container">
        <.content_header
          details={@details}
          content={@content}
          content_identity={@content_identity}
          current_user={@current_user}
        />

        <div class="flex flex-col gap-section px-page pt-cluster pb-page-y">
          <.watchers_section watchers={@watchers} locale={@current_user.settings.locale} />
          <.cast_section credits={@details.credits} />
        </div>
      </article>

      <.live_component
        :if={@episodes_open?}
        id={EpisodesModalLive.dom_id()}
        module={EpisodesModalLive}
        content_identity={@content_identity}
        title={title(@details)}
        season_numbers={season_numbers(@details)}
        initial_season={current_season_number(@content, @details)}
        in_library?={in_library?(@content)}
        current_user={@current_user}
        on_close={JS.push("close_episodes")}
      />
    </Layouts.app>
    """
  end

  attr :details, :any, required: true, doc: "a `MovieDetailsResponse` or a `TvDetailsResponse`"
  attr :content, :any, required: true, doc: "a `Content`, nil when WatchClub doesn't have it yet"
  attr :content_identity, ContentIdentity, required: true
  attr :current_user, User, required: true

  # The poster, the name, its facts, its genres and the overview, on the dimmed backdrop, then the
  # actions. Centered on phones, beside the poster on wide screens.
  defp content_header(assigns) do
    ~H"""
    <%!-- The app bar sits over the header --%>
    <header class="relative isolate pt-(--wc-app-bar-height)">
      <div
        :if={@details.backdrop_path}
        aria-hidden="true"
        class="absolute inset-0 -z-10 overflow-hidden"
      >
        <.tmdb_backdrop path={@details.backdrop_path} size="w1280" class="size-full object-cover" />
        <span class="absolute inset-0 bg-canvas/80"></span>
      </div>
      <div class="flex flex-col items-center gap-group px-page py-cluster text-center @3xl:flex-row @3xl:items-start @3xl:gap-cluster @3xl:py-section @3xl:text-left">
        <.tmdb_poster
          path={@details.poster_path}
          size="w342"
          class="w-28 shrink-0 shadow-card @3xl:w-44"
        />
        <div class="flex w-full min-w-0 flex-1 flex-col gap-group">
          <div class="flex flex-col gap-tight">
            <h1
              id="content-title"
              data-page-title
              class="font-heading text-3xl font-semibold text-balance @3xl:text-4xl"
            >
              {title(@details)}
            </h1>
            <.facts
              details={@details}
              content_identity={@content_identity}
              locale={@current_user.settings.locale}
            />
          </div>
          <ul
            :if={@details.genres != []}
            class="flex flex-wrap justify-center gap-tight @3xl:justify-start"
          >
            <li :for={genre <- @details.genres}>
              <.badge variant="secondary" size="sm">{genre.name}</.badge>
            </li>
          </ul>
          <p
            :if={@details.overview not in [nil, ""]}
            class="max-w-readable text-text-muted @max-3xl:line-clamp-3"
          >
            {@details.overview}
          </p>
          <.actions
            details={@details}
            content={@content}
            content_identity={@content_identity}
            current_user={@current_user}
          />
        </div>
      </div>
    </header>
    """
  end

  attr :details, :any, required: true
  attr :content_identity, ContentIdentity, required: true
  attr :locale, :atom, required: true

  # "🇺🇸 2022 · Movie · 3 hr 9 min · ★ 7.3": the original language's flag next to the year, as on
  # Browse's posters, and TMDB's rating, which opens the Content on TMDB.
  defp facts(assigns) do
    assigns =
      assign(assigns,
        language: Languages.to_name(assigns.details.original_language),
        length: length_label(assigns.details, assigns.locale),
        rating: Rating.from_tmdb(assigns.details)
      )

    ~H"""
    <p class="flex flex-wrap items-center justify-center gap-x-related gap-y-tight text-sm text-text-muted @3xl:justify-start">
      <span class="inline-flex items-center gap-tight">
        <span
          :if={@language}
          role="img"
          aria-label={dgettext("contents", "Original language: %{language}", language: @language)}
          title={dgettext("contents", "Original language: %{language}", language: @language)}
          class="text-base leading-none"
        >
          {Languages.to_flag(@details.original_language)}
        </span>
        {Time.maybe_year(release_date(@details))}
      </span>
      <span aria-hidden="true">·</span>
      <span>{ContentType.translated_label(@content_identity.type)}</span>
      <span :if={@length} aria-hidden="true">·</span>
      <span :if={@length}>{@length}</span>
      <span :if={@rating} aria-hidden="true">·</span>
      <.link
        :if={@rating}
        id="tmdb-rating"
        href={tmdb_url(@content_identity)}
        target="_blank"
        title={dgettext("contents", "See it on TMDB")}
        class="inline-flex items-center gap-tight font-semibold text-text hover:underline"
      >
        <Lucideicons.star class="size-icon-sm fill-current text-warning" />
        {WatchClub.Cldr.Number.to_string!(@rating,
          fractional_digits: 1,
          locale: UserLocale.to_cldr_locale_name(@locale)
        )}
        <Lucideicons.external_link class="size-icon-sm text-text-subtle" />
      </.link>
    </p>
    """
  end

  attr :details, :any, required: true
  attr :content, :any, required: true, doc: "a `Content`, or nil"
  attr :content_identity, ContentIdentity, required: true
  attr :current_user, User, required: true

  # Play, Resume or Request first, with how far the User got under it. For a TV Show, a caret
  # joined to Play opens every episode, or Episodes when there's no Play. Then Watch trailer and
  # Watched, which stay quiet.
  defp actions(assigns) do
    tv_show? = assigns.content_identity.type == :tv_show

    assigns =
      assign(assigns,
        tv_show?: tv_show?,
        episodes?: tv_show? and season_numbers(assigns.details) != [],
        in_library?: in_library?(assigns.content),
        finished?: finished?(assigns.content),
        trailer_url: trailer_url(assigns.details)
      )

    ~H"""
    <div class="flex flex-col gap-related @3xl:flex-row @3xl:flex-wrap @3xl:items-start @3xl:gap-x-cluster">
      <div class="flex w-full flex-col gap-tight @max-3xl:mx-auto @max-3xl:max-w-sm @3xl:w-auto">
        <.live_component
          id={PlayOrRequestButtonLive.dom_id(@content_identity)}
          module={PlayOrRequestButtonLive}
          content_identity={@content_identity}
          current_user={@current_user}
          size="lg"
          on_episodes={if @episodes? and @in_library?, do: JS.push("open_episodes")}
        />
        <.progress_line content={@content} locale={@current_user.settings.locale} />
      </div>
      <%!-- On wide screens, narrower buttons pulled left by their padding: even gaps on one line, and
      icons in line with Play once they wrap under it --%>
      <.cluster class="justify-center @3xl:-ml-related @3xl:justify-start @3xl:*:px-related!">
        <.button
          :if={@episodes? and !@in_library?}
          id="episodes-button"
          variant="overlay"
          size="lg"
          phx-click="open_episodes"
          aria-haspopup="dialog"
          class="phx-click-loading:cursor-progress phx-click-loading:opacity-60"
        >
          <:icon><Lucideicons.list_video /></:icon>
          {dgettext("contents", "Episodes")}
        </.button>
        <.button
          :if={@trailer_url}
          id="trailer-button"
          variant="overlay"
          size="lg"
          href={@trailer_url}
          target="_blank"
        >
          <:icon><Lucideicons.circle_play /></:icon>
          {dgettext("contents", "Watch trailer")}
          <:icon position="end">
            <Lucideicons.external_link class="size-icon-sm text-text-subtle" />
          </:icon>
        </.button>
        <%!-- Its label changes with its state, so it has no aria-pressed --%>
        <.button
          id="watched-button"
          variant="overlay"
          size="lg"
          phx-click="toggle_watched"
          title={watched_hint(@tv_show?, @finished?)}
        >
          <:icon>
            <Lucideicons.circle_check :if={@finished?} class="text-success" />
            <Lucideicons.circle :if={!@finished?} />
          </:icon>
          {if @finished?,
            do: dgettext("contents", "Watched"),
            else: dgettext("contents", "Mark as watched")}
        </.button>
      </.cluster>
    </div>
    """
  end

  attr :content, :any, required: true, doc: "a `Content`, or nil"
  attr :locale, :atom, required: true

  # How far the User got, under Resume: where they stopped a Movie, or the episode Play plays and
  # how much of the TV Show they finished.
  defp progress_line(assigns) do
    assigns = assign(assigns, :progress, progress(assigns.content, assigns.locale))

    ~H"""
    <div :if={@progress} class="flex flex-col gap-tight">
      <.progress_bar percent={@progress.percent} />
      <span class="text-xs text-text-muted">{@progress.label}</span>
    </div>
    """
  end

  attr :watchers, :list, required: true, doc: "the `Watcher`s, intentionally small: the Users"
  attr :locale, :atom, required: true

  # The other Users who watched it or are watching it, the latest first, each with a check or a
  # half circle, their name, their status and when they last watched it.
  defp watchers_section(assigns) do
    ~H"""
    <.page_section id="watchers-heading" title={dgettext("contents", "Who watched it")}>
      <.scroll_row :if={@watchers != []} id="watchers">
        <.person_tile
          :for={watcher <- @watchers}
          id={"watcher-#{watcher.user.id}"}
          name={watcher.user.username}
        >
          <:picture>
            <span class="relative">
              <%!-- Its id picks its color, as everywhere else --%>
              <.avatar
                id={watcher.user.id}
                name={watcher.user.username}
                size="lg"
                aria-hidden="true"
              />
              <span class="absolute -right-tight -bottom-tight flex size-icon items-center justify-center rounded-full bg-surface-raised ring-2 ring-canvas">
                <Lucideicons.check :if={watcher.status == :completed} class="size-3 text-success" />
                <Lucideicons.contrast
                  :if={watcher.status == :in_progress}
                  class="size-3 text-primary"
                />
              </span>
            </span>
          </:picture>
          <:line class="text-text-muted">{WatchStatus.translated_label(watcher.status)}</:line>
          <:line class="text-text-subtle">
            {Time.relative_from_now(watcher.last_watched_at, @locale)}
          </:line>
        </.person_tile>
      </.scroll_row>
      <p :if={@watchers == []} class="text-sm text-text-muted">
        {dgettext("contents", "Nobody has watched it yet.")}
      </p>
    </.page_section>
    """
  end

  attr :credits, :any, required: true, doc: "TMDB's `Credits`"

  # Who directed it, then who's in it, as round photos
  defp cast_section(assigns) do
    assigns = assign(assigns, :people, cast(assigns.credits))

    ~H"""
    <.page_section :if={@people != []} id="cast-heading" title={dgettext("contents", "Cast")}>
      <.scroll_row id="cast">
        <.person_tile :for={person <- @people} name={person.name}>
          <:picture>
            <span class="relative size-20 shrink-0 overflow-hidden rounded-full bg-surface-raised">
              <img
                :if={person.profile_path}
                src={"https://image.tmdb.org/t/p/w185#{person.profile_path}"}
                alt=""
                loading="lazy"
                class="absolute inset-0 size-full object-cover"
              />
              <span
                :if={!person.profile_path}
                class="absolute inset-0 flex items-center justify-center text-sm font-semibold text-text-muted"
              >
                {initials(person.name)}
              </span>
            </span>
          </:picture>
          <:line class="text-text-muted">{person.role}</:line>
        </.person_tile>
      </.scroll_row>
    </.page_section>
    """
  end

  attr :id, :string, required: true, doc: "its heading's id"
  attr :title, :string, required: true
  slot :inner_block, required: true

  # A section under the header: its heading, then what it holds
  defp page_section(assigns) do
    ~H"""
    <section aria-labelledby={@id} class="flex min-w-0 flex-col gap-group">
      <h2 id={@id} class="font-heading text-xl font-semibold">{@title}</h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :id, :string, default: nil
  attr :name, :string, required: true

  slot :picture, required: true

  slot :line, doc: "a line under the name" do
    attr :class, :any
  end

  # A person in a row of a section: their picture, their name, then a line or two about them
  defp person_tile(assigns) do
    ~H"""
    <div
      id={@id}
      class="flex w-24 shrink-0 snap-start flex-col items-center gap-related text-center"
    >
      {render_slot(@picture)}
      <span class="flex w-full flex-col">
        <span class="line-clamp-2 text-sm font-semibold">{@name}</span>
        <span :for={line <- @line} class={["truncate text-xs", line[:class]]}>
          {render_slot(line)}
        </span>
      </span>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     |> WatchClub.PubSub.subscribe_if_connected("history:global")
     |> assign(:episodes_open?, false)}
  end

  @impl true
  def handle_params(%{"tmdb_id" => tmdb_id}, _uri, socket) do
    %{live_action: type, current_user: user} = socket.assigns

    with {id, ""} <- Integer.parse(tmdb_id),
         {identity, {:ok, details}} <- get_details(type, id, user) do
      {:noreply,
       socket
       |> assign(details: details, content_identity: identity)
       |> load_content!()
       |> load_watchers!()}
    else
      _not_found ->
        {:noreply,
         socket
         |> put_flash(:error, dgettext("contents", "This movie or TV show doesn't exist"))
         |> push_navigate(to: ~p"/")}
    end
  end

  # The Content's identity, and what it is from TMDB
  defp get_details(:movie, tmdb_id, user),
    do: {ContentIdentity.for_movie(tmdb_id), Contents.get_movie_details(tmdb_id, actor: user)}

  defp get_details(:tv_show, tmdb_id, user),
    do: {ContentIdentity.for_tv_show(tmdb_id), Contents.get_tv_show_details(tmdb_id, actor: user)}

  @impl true
  def handle_event("open_episodes", _params, socket),
    do: {:noreply, assign(socket, :episodes_open?, true)}

  def handle_event("close_episodes", _params, socket),
    do: {:noreply, assign(socket, :episodes_open?, false)}

  def handle_event("toggle_watched", _params, socket) do
    %{content_identity: identity, content: content, current_user: user} = socket.assigns

    if finished?(content),
      do: History.mark_content_not_watched!(identity, actor: user),
      else: History.mark_content_watched!(identity, actor: user)

    {:noreply, socket}
  end

  # Another User's Watch Progress, from history:global, only changes Who watched it
  @impl true
  def handle_info(
        %Notification{resource: WatchProgress, data: %{user_id: user_id}} = notification,
        socket
      )
      when user_id != socket.assigns.current_user.id do
    if notification.metadata.content_identity == socket.assigns.content_identity,
      do: {:noreply, load_watchers!(socket)},
      else: {:noreply, socket}
  end

  def handle_info(%Notification{} = notification, socket) do
    %{content_identity: identity, current_user: user} = socket.assigns

    PlayOrRequestButtonLive.handle_pubsub_message(notification, user)

    case notification do
      %{resource: resource, metadata: %{content_identity: ^identity}}
      when resource in [Media, WatchProgress] ->
        if socket.assigns.episodes_open?, do: EpisodesModalLive.reload_episodes()
        {:noreply, load_content!(socket)}

      # Created when someone first marks it, or refreshed
      %{resource: Content, data: %Content{} = content} ->
        if ContentIdentity.from_content(content) == identity,
          do: {:noreply, socket |> load_content!() |> load_watchers!()},
          else: {:noreply, socket}

      _other ->
        {:noreply, socket}
    end
  end

  defp load_content!(socket) do
    %{content_identity: identity, current_user: user} = socket.assigns

    assign(
      socket,
      :content,
      Contents.get_content_by_external_id!(identity.external_id_source, identity.external_id,
        load: @content_load,
        not_found_error?: false,
        actor: user
      )
    )
  end

  defp load_watchers!(socket) do
    %{content_identity: identity, current_user: user} = socket.assigns
    assign(socket, :watchers, History.list_watchers!(identity, actor: user))
  end

  defp in_library?(content), do: content != nil and content.has_media?

  defp finished?(content), do: content != nil and content.actor_progress_status == :completed

  # Where the User stopped the Movie, or the episode Play plays and how much of the TV Show they
  # finished. Nil until they start, and once they finish.
  defp progress(%Content{actor_progress_status: :in_progress, type: :movie} = content, locale) do
    %{position_seconds: position, percent_watched: percent} =
      content.implementation.actor_progress

    %{
      percent: percent,
      label:
        dgettext("contents", "Stopped at %{time}",
          time: Time.minutes(max(div(trunc(position), 60), 1), locale)
        )
    }
  end

  defp progress(%Content{actor_progress_status: :in_progress, type: :tv_show} = content, _locale) do
    %{actor_percent_watched: percent, actor_next_episode: episode} = content.implementation
    # Never 0% once an episode is finished, nor 100% while one isn't
    bindings = [
      episode: episode.formatted_episode_number,
      percent: percent |> round() |> max(1) |> min(99)
    ]

    %{
      percent: percent,
      label:
        if episode.actor_progress_status == :in_progress do
          dgettext("contents", "On %{episode} · %{percent}% of the show", bindings)
        else
          dgettext("contents", "Next: %{episode} · %{percent}% of the show", bindings)
        end
    }
  end

  defp progress(_content, _locale), do: nil

  # The seasons of a TV Show with episodes, without its specials
  defp season_numbers(%TvDetailsResponse{} = details) do
    for season <- details.seasons,
        season.season_number >= 1 and season.episode_count > 0,
        do: season.season_number
  end

  # The season of the episode Play plays, else the first one
  defp current_season_number(
         %Content{implementation: %TvShow{actor_next_episode: %TvShowEpisode{} = episode}},
         _details
       ),
       do: episode.season_number

  defp current_season_number(_content, details), do: details |> season_numbers() |> List.first()

  defp title(%MovieDetailsResponse{title: title}), do: title
  defp title(%TvDetailsResponse{name: name}), do: name

  defp release_date(%MovieDetailsResponse{release_date: date}), do: date
  defp release_date(%TvDetailsResponse{first_air_date: date}), do: date

  defp length_label(%MovieDetailsResponse{runtime: minutes}, locale),
    do: Time.minutes(minutes, locale)

  defp length_label(%TvDetailsResponse{} = details, _locale) do
    case length(season_numbers(details)) do
      0 -> nil
      count -> dngettext("contents", "%{count} season", "%{count} seasons", count)
    end
  end

  # The director, then up to 17 actors in billing order
  defp cast(credits) do
    cast = (credits && credits.cast) || []
    crew = (credits && credits.crew) || []
    directors = crew |> Enum.filter(&(&1.job == "Director")) |> Enum.take(1)
    actors = cast |> Enum.sort_by(&(&1.order || 999_999)) |> Enum.take(17)

    (directors ++ actors)
    |> Enum.uniq_by(&(&1.id || &1.name))
    |> Enum.map(&%{name: &1.name, role: &1.character || &1.job, profile_path: &1.profile_path})
  end

  defp initials(name),
    do: name |> String.split(" ", trim: true) |> Enum.take(2) |> Enum.map_join(&String.first/1)

  defp tmdb_url(%ContentIdentity{type: :movie, external_id: id}),
    do: "https://www.themoviedb.org/movie/#{id}"

  defp tmdb_url(%ContentIdentity{type: :tv_show, external_id: id}),
    do: "https://www.themoviedb.org/tv/#{id}"

  # The official YouTube trailer, else any YouTube trailer, else a teaser
  defp trailer_url(details) do
    videos = (details.videos && details.videos.results) || []

    trailer =
      Enum.find(videos, &(&1.site == "YouTube" and &1.type == "Trailer" and &1.official)) ||
        Enum.find(videos, &(&1.site == "YouTube" and &1.type == "Trailer")) ||
        Enum.find(videos, &(&1.site == "YouTube" and &1.type == "Teaser"))

    if trailer && trailer.key not in [nil, ""],
      do: "https://www.youtube.com/watch?v=#{trailer.key}"
  end

  defp watched_hint(true = _tv_show?, true = _finished?),
    do: dgettext("contents", "Mark all as not watched")

  defp watched_hint(true, false), do: dgettext("contents", "Mark all as watched")
  defp watched_hint(false, true), do: dgettext("contents", "Mark as not watched")
  defp watched_hint(false, false), do: dgettext("contents", "Mark as watched")
end
