defmodule WatchClubWeb.Contents.ContentPage.EpisodesDrawerLive do
  @moduledoc """
  Every TV Show Episode of a TV Show, one season at a time, in a drawer from the right on wide
  screens and full screen on phones. Each aired episode has a check that marks it as watched or
  not, and Play once it's on the server. The season has a check too.

  The names, stills and air dates come from TMDB, the Media and the User's Watch Progress from
  WatchClub, which has no TV Show Episodes for a TV Show nobody marked or requested yet.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.TvShowEpisode.Calculations.FormattedEpisodeNumber

  @doc """
  The DOM id of the drawer, which only shows once at a time.
  """
  def dom_id, do: "episodes-drawer"

  @doc """
  Reloads the episodes when their Media or the User's Watch Progress change. Use it on the page
  that shows the drawer, which subscribes to `WatchClub.PubSub.subscribe_to_current_user_content_topics`.
  """
  def handle_pubsub_message(
        %Notification{resource: resource, metadata: %{content_identity: identity}} = notification,
        identity,
        %User{} = user
      )
      when resource in [Media, WatchProgress] do
    if resource == Media or notification.data.user_id == user.id,
      do: send_update(__MODULE__, id: dom_id(), reload: true)
  end

  def handle_pubsub_message(_notification, _identity, _user), do: nil

  attr :content_identity, ContentIdentity, required: true
  attr :title, :string, required: true, doc: "the TV Show's name"
  attr :season_numbers, :list, required: true
  attr :season_number, :integer, required: true, doc: "the season it opens on"
  attr :in_library?, :boolean, required: true
  attr :current_user, User, required: true
  attr :on_close, JS, required: true

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        aired_episodes: Enum.filter(assigns.episodes, &aired?/1),
        season_watched?: season_watched?(assigns.episodes)
      )

    ~H"""
    <div>
      <.modal
        id="episodes-drawer-modal"
        on_close={@on_close}
        class="@container m-0! ml-auto! h-svh! max-h-svh! w-full! max-w-none! rounded-none! border-y-0! border-r-0! md:w-[32rem]!"
      >
        <:title>{@title}</:title>
        <:description>
          {if @in_library?,
            do: dgettext("contents", "Play any episode, or mark what you've watched."),
            else:
              dgettext("contents", "It isn't on the server yet. Mark what you've watched elsewhere.")}
        </:description>

        <div class="flex items-center gap-related">
          <.scroll_row
            :if={length(@season_numbers) > 1}
            id="episodes-drawer-seasons"
            class="min-w-0 flex-1 [&_[data-scroll-track]]:gap-tight"
          >
            <button
              :for={number <- @season_numbers}
              id={"episodes-drawer-season-#{number}"}
              type="button"
              phx-click="select_season"
              phx-value-season={number}
              phx-target={@myself}
              aria-pressed={to_string(number == @season)}
              class={[
                "flex h-control-sm shrink-0 snap-start items-center rounded-full px-group text-sm font-semibold whitespace-nowrap transition-colors",
                number == @season && "bg-surface-selected text-text",
                number != @season && "text-text-muted hover:bg-surface-hover hover:text-text"
              ]}
            >
              {dgettext("contents", "Season %{number}", number: number)}
            </button>
          </.scroll_row>
          <span :if={length(@season_numbers) == 1} class="min-w-0 flex-1 text-sm font-semibold">
            {dgettext("contents", "Season %{number}", number: @season)}
          </span>
          <.button
            :if={@aired_episodes != []}
            id="episodes-drawer-season-watched"
            variant="ghost"
            size="sm"
            phx-click="toggle_season"
            phx-target={@myself}
            aria-pressed={to_string(@season_watched?)}
            aria-label={season_hint(@season, @season_watched?)}
            title={season_hint(@season, @season_watched?)}
            class="shrink-0"
          >
            <Lucideicons.circle_check :if={@season_watched?} class="size-icon text-success" />
            <Lucideicons.circle :if={!@season_watched?} class="size-icon" />
            <span class="@max-md:sr-only">
              {if @season_watched?,
                do: dgettext("contents", "Season watched"),
                else: dgettext("contents", "Mark season as watched")}
            </span>
          </.button>
        </div>

        <ol class="flex flex-col">
          <.episode_row
            :for={episode <- @episodes}
            episode={episode}
            in_library?={@in_library?}
            locale={@current_user.settings.locale}
            myself={@myself}
          />
        </ol>
      </.modal>
    </div>
    """
  end

  attr :episode, :map, required: true, doc: "TMDB's `details` and WatchClub's `episode`, or nil"
  attr :in_library?, :boolean, required: true
  attr :locale, :atom, required: true
  attr :myself, :any, required: true

  # Its still, with Play once it's on the server, its number and name, its length and a word on
  # where it is, its story, and a check to mark it as watched or not once it aired. The still is
  # grey while it isn't out, and when a TV Show on the server misses it.
  defp episode_row(assigns) do
    %{details: details, episode: episode} = assigns.episode
    aired? = aired?(assigns.episode)
    playable? = episode != nil and episode.has_media?
    watching? = episode != nil and episode.actor_progress_status == :in_progress

    assigns =
      assign(assigns,
        details: details,
        number: details.episode_number,
        aired?: aired?,
        playable?: playable?,
        watching?: watching?,
        watched?: watched?(assigns.episode),
        note: note(details, aired?, assigns.in_library? and !playable?, watching?, assigns.locale)
      )

    ~H"""
    <li id={"episode-#{@number}"} class="flex items-start gap-group py-related">
      <.tmdb_still
        size="w300"
        path={@details.still_path}
        class={[
          "w-28 shrink-0 rounded-control @md:w-40",
          (!@aired? or (@in_library? and !@playable?)) && "opacity-60 grayscale"
        ]}
      >
        <span :if={@playable?} class="absolute inset-0 grid place-items-center">
          <.button
            id={"episode-#{@number}-play"}
            variant="primary"
            size="icon"
            href={Url.player_link(@episode.episode)}
            aria-label={dgettext("contents", "Play episode %{number}", number: @number)}
            title={dgettext("contents", "Play episode %{number}", number: @number)}
            class="rounded-full! shadow-overlay"
          >
            <Lucideicons.play class="size-icon-sm" />
          </.button>
        </span>
        <.progress_bar
          :if={@watching?}
          percent={@episode.episode.actor_progress.percent_watched}
          class="absolute inset-x-0 bottom-0 rounded-none!"
        />
      </.tmdb_still>
      <div class="flex min-w-0 flex-1 flex-col gap-tight">
        <span>
          <span class="font-semibold">
            {FormattedEpisodeNumber.format(@details.season_number, @number)}
          </span>
          · {@details.name}
        </span>
        <span class="flex flex-wrap gap-x-related text-xs text-text-muted">
          <span :if={@details.runtime}>{Time.runtime(@details.runtime)}</span>
          <span :if={@note} class="font-semibold">{@note}</span>
        </span>
        <span
          :if={@details.overview not in [nil, ""]}
          class="line-clamp-2 max-w-readable text-sm text-text-muted"
        >
          {@details.overview}
        </span>
      </div>
      <.button
        :if={@aired?}
        id={"episode-#{@number}-watched"}
        variant="ghost"
        size="icon"
        phx-click="toggle_episode"
        phx-value-episode={@number}
        phx-target={@myself}
        aria-pressed={to_string(@watched?)}
        aria-label={
          if @watched?,
            do: dgettext("contents", "Mark episode %{number} as not watched", number: @number),
            else: dgettext("contents", "Mark episode %{number} as watched", number: @number)
        }
        title={
          if @watched?,
            do: dgettext("contents", "Watched"),
            else: dgettext("contents", "Mark as watched")
        }
        class="shrink-0"
      >
        <Lucideicons.circle_check :if={@watched?} class="size-icon text-success" />
        <Lucideicons.circle :if={!@watched?} class="size-icon" />
      </.button>
      <span :if={!@aired?} class="size-control-md shrink-0"></span>
    </li>
    """
  end

  # A word under an episode: when it airs, that a TV Show on the server misses it, or that the User
  # is watching it
  defp note(%{air_date: nil}, false = _aired?, _missing?, _watching?, _locale),
    do: dgettext("contents", "Not out yet")

  defp note(%{air_date: date}, false, _missing?, _watching?, locale),
    do: dgettext("contents", "Out on %{date}", date: Time.long_date(date, locale))

  defp note(_details, true, true = _missing?, _watching?, _locale),
    do: dgettext("contents", "Not on the server yet")

  defp note(_details, true, false, true = _watching?, _locale),
    do: dgettext("contents", "You're watching it")

  defp note(_details, _aired?, _missing?, _watching?, _locale), do: nil

  @impl true
  def update(%{reload: true}, socket), do: {:ok, load_episodes!(socket)}

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:season, fn -> assigns.season_number end)
     |> load_episodes!()}
  end

  @impl true
  def handle_event("select_season", %{"season" => season}, socket) do
    {:noreply, socket |> assign(:season, String.to_integer(season)) |> load_episodes!()}
  end

  def handle_event("toggle_episode", %{"episode" => number}, socket) do
    number = String.to_integer(number)
    episode = Enum.find(socket.assigns.episodes, &(&1.details.episode_number == number))

    mark!(
      socket,
      %{season_number: socket.assigns.season, episode_number: number},
      watched?(episode)
    )

    {:noreply, socket}
  end

  def handle_event("toggle_season", _params, socket) do
    mark!(
      socket,
      %{season_number: socket.assigns.season},
      season_watched?(socket.assigns.episodes)
    )

    {:noreply, socket}
  end

  defp mark!(socket, episodes, true = _watched?),
    do:
      History.mark_content_not_watched!(socket.assigns.content_identity, episodes,
        actor: socket.assigns.current_user
      )

  defp mark!(socket, episodes, false),
    do:
      History.mark_content_watched!(socket.assigns.content_identity, episodes,
        actor: socket.assigns.current_user
      )

  # TMDB's episodes of the season, each with WatchClub's, or nil
  defp load_episodes!(socket) do
    %{content_identity: identity, season: season, current_user: user} = socket.assigns
    tmdb_id = String.to_integer(identity.external_id)

    ours =
      tmdb_id
      |> Contents.get_episodes_for_show!(
        query: [filter: [season_number: season]],
        load: [:has_media?, :videos, :actor_progress_status, :actor_progress],
        actor: user
      )
      |> Map.new(&{&1.episode_number, &1})

    episodes =
      for details <- Contents.get_tv_show_season_details!(tmdb_id, season, actor: user).episodes,
          do: %{details: details, episode: Map.get(ours, details.episode_number)}

    assign(socket, :episodes, episodes)
  end

  # TvShowEpisode.aired?, from TMDB's air date: WatchClub may not have the episode
  defp aired?(%{details: %{air_date: date}}),
    do: date != nil and Date.compare(date, Date.utc_today()) != :gt

  defp watched?(%{episode: episode}),
    do: episode != nil and episode.actor_progress_status == :completed

  defp season_watched?(episodes) do
    aired = Enum.filter(episodes, &aired?/1)
    aired != [] and Enum.all?(aired, &watched?/1)
  end

  defp season_hint(season, true),
    do: dgettext("contents", "Mark season %{number} as not watched", number: season)

  defp season_hint(season, false),
    do: dgettext("contents", "Mark season %{number} as watched", number: season)
end
