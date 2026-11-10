defmodule WatchClubWeb.Contents.ContentPage do
  @moduledoc """
  The page of a Movie or a TV Show: its persisted metadata, how far the User got, with Play or
  Resume, every TV Show Episode in a modal, the User's Conversations about it, with Recommend
  Content, the other Users who watched it, and the Playlists that hold it, with Add to Playlist.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.TmdbBackdrop
  import WatchClubWeb.Components.Contents.StarRating
  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Contents.IncompleteBadge
  import WatchClubWeb.Components.Accounts.UserAvatar
  import WatchClubWeb.Components.Conversations.{Recipients, RecommendationText}
  import WatchClubWeb.Components.Medias.DownloadMenu
  import WatchClubWeb.Components.Playlists.PlaylistLink
  import WatchClubWeb.Contents.ContentPage.AddToPlaylistModal

  alias WatchClub.Contents.{
    Content,
    ContentIdentity,
    ContentType,
    Genre,
    MetadataUnavailable,
    TvShow,
    TvShowEpisode
  }

  alias WatchClub.Conversations
  alias WatchClub.Conversations.{Conversation, Message, Participant}
  alias WatchClub.Languages
  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive
  alias WatchClubWeb.Contents.ContentPage.{EpisodesModalLive, RecommendModalLive}

  # The Content and its implementation data shown on the page.
  @content_load [
    :has_media?,
    :title,
    :overview,
    :poster_path,
    :backdrop_path,
    :actor_progress_status,
    :incomplete?,
    implementation: %{
      load: [
        movie: [videos: [:media, :default_video_track]],
        sports_event: [videos: [:media, :default_video_track]],
        tv_show: [:actor_next_episode, :season_numbers, :season_count]
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
      playback_session={@playback_session}
      title={title(@content)}
      content_page?
    >
      <div :if={!@content} class="@container pt-(--wc-app-bar-height)">
        <.page width="full">
          <.stack
            id="content-loading"
            role="status"
            class="items-center py-section text-center text-text-muted @lg:flex-row @lg:justify-center"
          >
            <Lucideicons.loader_circle
              aria-hidden="true"
              class="size-icon-lg shrink-0 motion-safe:animate-spin"
            />
            <h1 id="content-title" data-page-title class="font-heading text-xl font-semibold">
              {dgettext("contents", "Loading content…")}
            </h1>
          </.stack>
        </.page>
      </div>

      <article :if={@content} aria-labelledby="content-title" class="@container">
        <.content_header
          content={@content}
          content_identity={@content_identity}
          current_user={@current_user}
          on_tv?={@on_tv?}
        />

        <div class="flex flex-col gap-section px-page pt-cluster pb-page-y">
          <.conversations_section conversations={@conversations} current_user={@current_user} />
          <.watchers_section watchers={@watchers} locale={@current_user.settings.locale} />
          <.playlists_section
            playlists={Enum.filter(@playlists, & &1.holds_content?)}
            current_user={@current_user}
          />
          <.cast_section people={localization(@content).cast} />
        </div>
      </article>

      <.live_component
        :if={@content && @episodes_open?}
        id={EpisodesModalLive.dom_id()}
        module={EpisodesModalLive}
        content_identity={@content_identity}
        title={title(@content)}
        season_numbers={season_numbers(@content)}
        initial_season={current_season_number(@content)}
        in_library?={in_library?(@content)}
        current_user={@current_user}
        on_close={JS.push("close_episodes")}
      />

      <.live_component
        :if={@content && @recommend_open?}
        id="recommend"
        module={RecommendModalLive}
        content_identity={@content_identity}
        title={title(@content)}
        recommended_by_ids={
          for conversation <- @conversations,
              conversation.recommended_by_id != @current_user.id,
              do: conversation.recommended_by_id
        }
        current_user={@current_user}
        on_close={fn -> send(self(), :close_recommend) end}
      />

      <.add_to_playlist_modal
        :if={@content && @new_playlist_form}
        title={title(@content)}
        playlists={Enum.filter(@playlists, & &1.editable_by?)}
        new_playlist_form={@new_playlist_form}
        current_user={@current_user}
      />
    </Layouts.app>
    """
  end

  attr :content, Content, required: true
  attr :content_identity, ContentIdentity, required: true
  attr :current_user, User, required: true
  attr :on_tv?, :boolean, required: true, doc: "whether Play plays on the User's TV"

  # The poster, the name, its facts, its genres and the overview, on the dimmed backdrop, then the
  # actions. Centered on phones, beside the poster on wide screens.
  defp content_header(assigns) do
    ~H"""
    <%!-- The app bar sits over the header --%>
    <header class="relative isolate pt-(--wc-app-bar-height)">
      <div
        :if={@content.backdrop_path}
        aria-hidden="true"
        class="absolute inset-0 -z-10 overflow-hidden"
      >
        <.tmdb_backdrop path={@content.backdrop_path} size="w1280" class="size-full object-cover" />
        <span class="absolute inset-0 bg-canvas/80"></span>
      </div>
      <div class="flex flex-col items-center gap-group px-page py-cluster text-center @3xl:flex-row @3xl:items-start @3xl:gap-cluster @3xl:py-section @3xl:text-left">
        <.tmdb_poster
          path={@content.poster_path}
          size="w342"
          class="w-28 shrink-0 shadow-card @3xl:w-44"
        >
          <.incomplete_badge
            :if={@content.incomplete?}
            id="content-incomplete"
            class="absolute top-related right-related"
          />
        </.tmdb_poster>
        <div class="flex w-full min-w-0 flex-1 flex-col gap-group">
          <div class="flex flex-col gap-tight">
            <h1
              id="content-title"
              data-page-title
              class="font-heading text-3xl font-semibold text-balance @3xl:text-4xl"
            >
              {title(@content)}
            </h1>
            <.facts
              content={@content}
              content_identity={@content_identity}
              locale={@current_user.settings.locale}
            />
          </div>
          <ul
            :if={@content.genres != []}
            class="flex flex-wrap justify-center gap-tight @3xl:justify-start"
          >
            <li :for={genre <- @content.genres}>
              <.badge variant="secondary" size="sm">{Genre.translated_label(genre)}</.badge>
            </li>
          </ul>
          <.overview
            :if={@content.overview not in [nil, ""]}
            text={@content.overview}
            lang={if @content.type == :sports_event, do: "en"}
          />
          <.actions
            content={@content}
            content_identity={@content_identity}
            current_user={@current_user}
            on_tv?={@on_tv?}
          />
        </div>
      </div>
    </header>
    """
  end

  attr :text, :string, required: true
  attr :lang, :string, default: nil, doc: "set when it isn't in the User's language"

  # Clamped to a few lines, with More to read a long one whole, such as a Sports Event's
  defp overview(assigns) do
    ~H"""
    <div class="flex max-w-readable flex-col items-center gap-tight @3xl:items-start">
      <p id="content-overview" lang={@lang} class="text-text-muted line-clamp-3 @3xl:line-clamp-5">
        {@text}
      </p>
      <.button
        :if={String.length(@text) > 300}
        id="content-overview-toggle"
        variant="ghost"
        size="sm"
        aria-controls="content-overview"
        aria-expanded="false"
        phx-click={
          JS.toggle_class("line-clamp-3 @3xl:line-clamp-5", to: "#content-overview")
          |> JS.toggle(to: "#content-overview-toggle [data-label]", display: "inline")
          |> JS.toggle_attribute({"aria-expanded", "true", "false"})
        }
      >
        <span data-label>{dgettext("contents", "More")}</span>
        <span data-label class="hidden">{dgettext("contents", "Less")}</span>
      </.button>
    </div>
    """
  end

  attr :content, Content, required: true
  attr :content_identity, ContentIdentity, required: true
  attr :locale, :atom, required: true

  # "🇺🇸 2022 · Movie · 3 hr 9 min · ★ 7.3": the original language's flag next to the year, as on
  # Browse's posters, and the persisted Rating, which opens the Content on TMDB. A Sports Event
  # shows its league instead of a length: "2025 · Sports Event · UFC".
  defp facts(assigns) do
    assigns =
      assign(assigns,
        language: Languages.to_name(assigns.content.original_language),
        length: detail_label(assigns.content, assigns.locale),
        rating: assigns.content.rating
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
          {Languages.to_flag(@content.original_language)}
        </span>
        {release_label(@content, @locale)}
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
        class="inline-flex items-center gap-tight text-text hover:underline"
      >
        <.star_rating rating={@rating} locale={@locale} />
        <Lucideicons.external_link class="size-icon-sm text-text-subtle" />
      </.link>
    </p>
    """
  end

  attr :content, Content, required: true
  attr :content_identity, ContentIdentity, required: true
  attr :current_user, User, required: true
  attr :on_tv?, :boolean, required: true, doc: "whether Play plays on the User's TV"

  # Play, Resume or Request first, or how far the request got. Then round Episodes for a TV Show,
  # Watch trailer, Download for a Movie in the Library and Watched, which stay quiet.
  defp actions(assigns) do
    tv_show? = assigns.content_identity.type == :tv_show

    assigns =
      assign(assigns,
        tv_show?: tv_show?,
        episodes?: tv_show? and season_numbers(assigns.content) != [],
        videos: if(tv_show?, do: [], else: assigns.content.implementation.videos),
        finished?: finished?(assigns.content),
        trailer_url: localization(assigns.content).trailer_url
      )

    ~H"""
    <div class="flex flex-col gap-group @3xl:flex-row @3xl:flex-wrap @3xl:items-start @3xl:gap-x-cluster">
      <.live_component
        id={PlayOrRequestButtonLive.dom_id(@content_identity)}
        module={PlayOrRequestButtonLive}
        content_identity={@content_identity}
        current_user={@current_user}
        on_tv?={@on_tv?}
        size="lg"
        class="w-full @max-3xl:mx-auto @max-3xl:max-w-sm @3xl:w-auto @3xl:min-w-64"
      />
      <div class="flex justify-center gap-group @3xl:justify-start">
        <.round_action
          :if={@episodes?}
          id="episodes-button"
          label={dgettext("contents", "Episodes")}
          phx-click="open_episodes"
          aria-haspopup="dialog"
          class="phx-click-loading:cursor-progress phx-click-loading:opacity-60"
        >
          <Lucideicons.list_video />
        </.round_action>
        <.round_action
          :if={@trailer_url}
          id="trailer-button"
          label={dgettext("contents", "Watch trailer")}
          href={@trailer_url}
          target="_blank"
        >
          <Lucideicons.circle_play />
        </.round_action>
        <.download_menu :if={@videos != []} id="download" videos={@videos}>
          <:trigger :let={download_link}>
            <.round_action
              id="download-button"
              label={dgettext("contents", "Download")}
              {download_link}
            >
              <Lucideicons.download />
            </.round_action>
          </:trigger>
        </.download_menu>
        <%!-- Its label changes with its state, so it has no aria-pressed --%>
        <.round_action
          id="watched-button"
          label={
            if @finished?,
              do: dgettext("contents", "Watched"),
              else: dgettext("contents", "Mark as watched")
          }
          phx-click="toggle_watched"
          title={watched_hint(@tv_show?, @finished?)}
        >
          <Lucideicons.circle_check :if={@finished?} class="text-success" />
          <Lucideicons.circle :if={!@finished?} />
        </.round_action>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(href target download),
    doc: "a link with an href, else a button"

  slot :inner_block, required: true, doc: "its icon"

  # A quiet action beside Play: its icon in a circle, with a small label under it
  defp round_action(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={if @rest[:href], do: "a", else: "button"}
      id={@id}
      class={[
        "group/action flex w-20 flex-col items-center gap-tight text-xs text-text-muted",
        @class
      ]}
      {@rest}
    >
      <span class="grid size-control-lg place-items-center rounded-full border border-border bg-surface-raised text-text transition-colors group-hover/action:bg-surface-hover group-active/action:bg-surface-active [&_svg]:size-icon">
        {render_slot(@inner_block)}
      </span>
      {@label}
    </.dynamic_tag>
    """
  end

  attr :conversations, :list,
    required: true,
    doc: "the User's Conversations about it, intentionally small"

  attr :current_user, User, required: true

  # The User's Conversations about it, then a card to Recommend Content, which starts another
  defp conversations_section(assigns) do
    ~H"""
    <.page_section id="conversations-heading" title={dgettext("contents", "Conversations")}>
      <.scroll_row id="conversations">
        <.conversation_card
          :for={conversation <- @conversations}
          conversation={conversation}
          current_user={@current_user}
        />
        <button
          id="recommend-card"
          type="button"
          phx-click="open_recommend"
          aria-haspopup="dialog"
          class="flex w-80 shrink-0 snap-start items-center gap-group rounded-card border border-accent-border bg-accent-bg p-group text-left shadow-card transition-colors hover:border-accent"
        >
          <span class="grid size-control-lg shrink-0 place-items-center rounded-full border border-accent-border text-accent">
            <Lucideicons.send class="size-icon" />
          </span>
          <span class="flex min-w-0 flex-col gap-tight">
            <span class="font-semibold text-accent">{dgettext("contents", "Recommend")}</span>
            <span class="text-sm text-text-muted">
              {dgettext(
                "contents",
                "Recommend it to people, with a message if you want. It starts a conversation."
              )}
            </span>
          </span>
        </button>
      </.scroll_row>
    </.page_section>
    """
  end

  attr :conversation, Conversation, required: true
  attr :current_user, User, required: true

  # A Conversation read as a sentence: who recommended it and when, its text as a quote, then who
  # it went to. It opens the Conversation in the Inbox.
  defp conversation_card(assigns) do
    ~H"""
    <.link
      id={"conversation-#{@conversation.id}"}
      navigate={~p"/inbox/#{@conversation.id}"}
      class="flex w-80 shrink-0 snap-start flex-col gap-group rounded-card border border-border-subtle bg-surface p-group text-left shadow-card transition-colors hover:bg-surface-hover"
    >
      <span class="flex flex-col gap-related">
        <span class="flex items-center gap-related text-sm">
          <span aria-hidden="true"><.user_avatar user={@conversation.recommended_by} /></span>
          <span class="min-w-0 flex-1 truncate text-text-muted">
            {recommended_it(@conversation, @current_user)}
          </span>
          <span class="shrink-0 text-xs text-text-subtle">
            {Time.relative_from_now(@conversation.inserted_at, @current_user.settings.locale)}
          </span>
        </span>
        <.recommendation_text
          :if={@conversation.recommendation.body}
          body={@conversation.recommendation.body}
          class="text-lg"
        />
      </span>
      <span class="line-clamp-2 text-xs text-text-muted">{to_recipients(assigns)}</span>
    </.link>
    """
  end

  # "to [avatars] you, leadelpeut and vinz"
  defp to_recipients(assigns) do
    recipients =
      gtcomponent(~H"""
      <.recipients conversation={@conversation} current_user={@current_user} ring="ring-surface" />
      """)

    raw(dgettext("contents", "to %{recipients}", recipients: recipients))
  end

  defp recommended_it(%Conversation{recommended_by_id: id}, %User{id: id}),
    do: dgettext("contents", "You recommended it")

  defp recommended_it(conversation, _user) do
    raw(
      dgettext("contents", "%{recommender} recommended it",
        recommender: gtspan(username(conversation.recommended_by), "font-semibold text-text")
      )
    )
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

  attr :playlists, :list, required: true, doc: "the Playlists the User sees that hold it"
  attr :current_user, User, required: true

  # The Playlists the User sees that hold it, with Add to playlist, or the empty state
  defp playlists_section(assigns) do
    ~H"""
    <.page_section
      id="playlists-heading"
      title={dgettext("playlists", "In playlists")}
      class="max-w-readable"
    >
      <:action :if={@playlists != []}>
        <.button
          id="add-to-playlist"
          variant="secondary"
          size="sm"
          phx-click="open_add_to_playlist"
        >
          <:icon><Lucideicons.list_plus /></:icon>
          {dgettext("playlists", "Add to playlist")}
        </.button>
      </:action>
      <ul :if={@playlists != []} class="-mx-related flex flex-col gap-px">
        <li :for={playlist <- @playlists}>
          <.playlist_link
            playlist={playlist}
            current_user={@current_user}
            navigate={~p"/playlists/#{playlist.id}"}
          />
        </li>
      </ul>
      <.empty :if={@playlists == []} id="no-playlists">
        <:icon><Lucideicons.list /></:icon>
        <:title>{dgettext("playlists", "Not in your playlists yet")}</:title>
        <:description>
          {dgettext("playlists", "Save it to one of your playlists, or to a shared one you can edit.")}
        </:description>
        <.button id="empty-add-to-playlist" variant="secondary" phx-click="open_add_to_playlist">
          <:icon><Lucideicons.list_plus /></:icon>
          {dgettext("playlists", "Add to playlist")}
        </.button>
      </.empty>
    </.page_section>
    """
  end

  attr :people, :list, required: true, doc: "the persisted cast, intentionally small"

  # Who directed it, then who's in it, as round photos
  defp cast_section(assigns) do
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
     |> assign(episodes_open?: false, recommend_open?: false, new_playlist_form: nil)}
  end

  @impl true
  def handle_params(%{"sportarr_id" => sportarr_id}, _uri, socket),
    do: {:noreply, show_content(socket, ContentIdentity.for_sports_event(sportarr_id))}

  def handle_params(%{"tmdb_id" => tmdb_id}, _uri, socket) do
    case Integer.parse(tmdb_id) do
      {id, ""} ->
        {:noreply, show_content(socket, content_identity_for(socket.assigns.live_action, id))}

      _invalid_url ->
        {:noreply,
         socket
         |> put_flash(:error, dgettext("contents", "This movie or TV show doesn't exist"))
         |> push_navigate(to: ~p"/")}
    end
  end

  defp show_content(socket, identity) do
    user = socket.assigns.current_user
    otel_context = OpenTelemetry.Ctx.get_current()

    socket
    |> assign(content_identity: identity)
    |> load_content!()
    |> load_watchers!()
    |> load_conversations!()
    |> load_playlists!()
    |> start_async(:refresh_content, fn ->
      OpenTelemetry.Ctx.attach(otel_context)
      Contents.get_or_refresh_content(identity, actor: user)
    end)
  end

  @impl true
  def handle_async(:refresh_content, {:ok, {:ok, _content}}, socket), do: {:noreply, socket}

  def handle_async(:refresh_content, {:ok, {:error, %{errors: errors}}}, socket) do
    message =
      if Enum.any?(errors, &match?(%MetadataUnavailable{reason: :not_found}, &1)),
        do: dgettext("contents", "This movie or TV show doesn't exist"),
        else: dgettext("contents", "Content details are unavailable. Please try again later.")

    {:noreply, socket |> put_flash(:error, message) |> push_navigate(to: ~p"/")}
  end

  # The Content's identity from the URL
  defp content_identity_for(:movie, tmdb_id), do: ContentIdentity.for_movie(tmdb_id)
  defp content_identity_for(:tv_show, tmdb_id), do: ContentIdentity.for_tv_show(tmdb_id)

  @impl true
  def handle_event("open_episodes", _params, socket),
    do: {:noreply, assign(socket, :episodes_open?, true)}

  def handle_event("close_episodes", _params, socket),
    do: {:noreply, assign(socket, :episodes_open?, false)}

  def handle_event("open_recommend", _params, socket),
    do: {:noreply, assign(socket, :recommend_open?, true)}

  def handle_event("open_add_to_playlist", _params, socket) do
    form = Playlists.form_to_create_playlist(actor: socket.assigns.current_user)
    {:noreply, assign(socket, :new_playlist_form, to_form(form))}
  end

  def handle_event("close_add_to_playlist", _params, socket),
    do: {:noreply, assign(socket, :new_playlist_form, nil)}

  def handle_event("toggle_in_playlist", %{"playlist_id" => playlist_id}, socket) do
    %{playlists: playlists, content: content, content_identity: identity, current_user: user} =
      socket.assigns

    if Enum.find(playlists, &(&1.id == playlist_id)).holds_content?,
      do: Playlists.remove_from_playlist!(playlist_id, content.id, actor: user),
      else: Playlists.add_to_playlist!(playlist_id, identity, actor: user)

    {:noreply, socket}
  end

  def handle_event("validate_new_playlist", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.new_playlist_form, params)
    {:noreply, assign(socket, :new_playlist_form, form)}
  end

  # A new Playlist that starts with the Content
  def handle_event("create_playlist_with_content", %{"form" => params}, socket) do
    %{new_playlist_form: form, content_identity: identity, current_user: user} = socket.assigns

    case AshPhoenix.Form.submit(form, params: params) do
      {:ok, playlist} ->
        Playlists.add_to_playlist!(playlist.id, identity, actor: user)
        form = Playlists.form_to_create_playlist(actor: user)
        {:noreply, assign(socket, :new_playlist_form, to_form(form))}

      {:error, form} ->
        {:noreply, assign(socket, :new_playlist_form, form)}
    end
  end

  def handle_event("toggle_watched", _params, socket) do
    %{content_identity: identity, content: content, current_user: user} = socket.assigns

    if finished?(content),
      do: History.mark_content_not_watched!(identity, actor: user),
      else: History.mark_content_watched!(identity, actor: user)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:close_recommend, socket),
    do: {:noreply, assign(socket, :recommend_open?, false)}

  # A Playlist the User sees, or what it holds, changed. It may also be new to them, or gone.
  def handle_info(%Notification{resource: resource}, socket)
      when resource in [Playlist, PlaylistAccess, PlaylistItem],
      do: {:noreply, load_playlists!(socket)}

  # Another User's Watch Progress, from history:global, only changes Who watched it
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

      # Created when someone first marks it or recommends it, or refreshed
      %{resource: Content, data: %Content{} = content} ->
        if ContentIdentity.from_content(content) == identity,
          do:
            {:noreply,
             socket
             |> load_content!()
             |> load_watchers!()
             |> then(fn socket ->
               if socket.assigns.episodes_open?, do: EpisodesModalLive.reload_episodes()
               socket
             end)},
          else: {:noreply, socket}

      # A Conversation about it that the User is in started, or got a Message
      %{resource: resource, metadata: %{content_id: content_id}}
      when resource in [Participant, Message] ->
        if socket.assigns.content && socket.assigns.content.id == content_id,
          do: {:noreply, load_conversations!(socket)},
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
      Contents.get_content_by_identity!(identity,
        not_found_error?: false,
        load: @content_load,
        actor: user
      )
    )
  end

  defp load_conversations!(%{assigns: %{content: nil}} = socket),
    do: assign(socket, :conversations, [])

  defp load_conversations!(socket) do
    %{content: content, current_user: user} = socket.assigns

    assign(
      socket,
      :conversations,
      Conversations.list_conversations!(%{content_id: content.id},
        load: [:recommendation, :recommended_by, recipients: [:user]],
        actor: user
      )
    )
  end

  # Intentionally small: a User sees a handful of Playlists. In playlists shows the ones that hold
  # the Content, and Add to Playlist the ones they can edit, theirs first.
  defp load_playlists!(socket) do
    %{content_identity: identity, current_user: user} = socket.assigns

    playlists =
      Playlists.list_playlists!(
        load: [
          :movie_count,
          :tv_show_count,
          :sports_event_count,
          :owner,
          accesses: [:user],
          editable_by?: %{user_id: user.id},
          holds_content?: %{content_identity: identity}
        ],
        actor: user
      )
      |> Enum.sort_by(&(&1.owner_id != user.id))

    socket
    |> assign(:playlists, playlists)
    |> WatchClub.PubSub.subscribe_to_playlists(playlists)
  end

  defp load_watchers!(socket) do
    %{content_identity: identity, current_user: user} = socket.assigns
    assign(socket, :watchers, History.list_watchers!(identity, actor: user))
  end

  defp in_library?(content), do: content != nil and content.has_media?

  defp finished?(content), do: content != nil and content.actor_progress_status == :completed

  # A Movie's or a TV Show's cast, trailer and runtime. A Sports Event has none.
  defp localization(%Content{implementation: %{best_localization: %{} = localization}}),
    do: localization

  defp localization(_content), do: %{runtime: nil, cast: [], trailer_url: nil}

  defp title(nil), do: dgettext("contents", "Loading content…")
  defp title(content), do: content.title

  # The season of the episode Play plays, else the first one
  defp current_season_number(%Content{
         implementation: %TvShow{actor_next_episode: %TvShowEpisode{} = episode}
       }),
       do: episode.season_number

  defp current_season_number(content), do: content |> season_numbers() |> List.first()

  defp season_numbers(%Content{type: :tv_show, implementation: show}), do: show.season_numbers
  defp season_numbers(%Content{}), do: []

  # When it came out: the year, or the day of a Sports Event
  defp release_label(%Content{type: :sports_event, release_date: %Date{} = date}, locale),
    do: Time.long_date(date, locale)

  defp release_label(content, _locale), do: Time.maybe_year(content.release_date)

  # The length of a Movie, the seasons of a TV Show, or the league of a Sports Event
  defp detail_label(%Content{type: :movie} = content, locale),
    do: Time.minutes(localization(content).runtime, locale)

  defp detail_label(%Content{type: :sports_event, implementation: event}, _locale),
    do: event.league_name

  defp detail_label(%Content{type: :tv_show, implementation: show}, _locale) do
    case show.season_count do
      0 -> nil
      count -> dngettext("contents", "%{count} season", "%{count} seasons", count)
    end
  end

  defp initials(name),
    do: name |> String.split(" ", trim: true) |> Enum.take(2) |> Enum.map_join(&String.first/1)

  defp tmdb_url(%ContentIdentity{type: :movie, external_id: id}),
    do: "https://www.themoviedb.org/movie/#{id}"

  defp tmdb_url(%ContentIdentity{type: :tv_show, external_id: id}),
    do: "https://www.themoviedb.org/tv/#{id}"

  defp watched_hint(true = _tv_show?, true = _finished?),
    do: dgettext("contents", "Mark all as not watched")

  defp watched_hint(true, false), do: dgettext("contents", "Mark all as watched")
  defp watched_hint(false, true), do: dgettext("contents", "Mark as not watched")
  defp watched_hint(false, false), do: dgettext("contents", "Mark as watched")
end
