defmodule WatchClubWeb.Contents.ContentPage.EpisodesModalLive do
  @moduledoc """
  Every TV Show Episode of a TV Show, one season at a time, in a big modal, full screen on phones.
  Each aired episode has a check that marks it as watched or not, and Play once it's in the
  Library. The season has a check too.

  TMDB gives a season's episodes, with their names, stills and air dates, and WatchClub their
  Media and the User's Watch Progress. WatchClub has no TV Show Episodes for a TV Show nobody
  marked or requested yet.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Contents.TmdbPoster

  @doc """
  The DOM id of the modal, which shows at most once on a page.
  """
  def dom_id, do: "episodes"

  @doc """
  Reloads the episodes' Media and the User's Watch Progress on them, once they changed.
  """
  def reload_episodes, do: send_update(__MODULE__, id: dom_id(), reload_episodes: true)

  attr :content_identity, ContentIdentity, required: true
  attr :title, :string, required: true, doc: "the TV Show's name"
  attr :season_numbers, :list, required: true
  attr :initial_season, :integer, required: true, doc: "the season it opens on"
  attr :in_library?, :boolean, required: true
  attr :current_user, User, required: true
  attr :on_close, JS, required: true

  @impl true
  def render(assigns) do
    rows = rows(assigns.season, assigns.episodes)

    assigns =
      assign(assigns,
        rows: rows,
        any_aired?: Enum.any?(rows, &aired?/1),
        season_watched?: season_watched?(rows)
      )

    ~H"""
    <div>
      <%!-- As wide as its size, whatever the season's episodes --%>
      <.modal
        id="episodes-modal"
        phone="full_screen"
        size="lg"
        on_close={@on_close}
        class="w-full"
      >
        <:title>{@title}</:title>
        <:description>
          {if @in_library?,
            do: dgettext("contents", "Play any episode, or mark what you've watched."),
            else:
              dgettext("contents", "It isn't in the library yet. Mark what you've watched elsewhere.")}
        </:description>

        <%!-- A container for the rows' breakpoints --%>
        <div class="@container flex flex-col gap-group">
          <div class="flex flex-col gap-related">
            <.scroll_row
              :if={length(@season_numbers) > 1}
              id="episodes-modal-seasons"
              variant="chips"
            >
              <button
                :for={number <- @season_numbers}
                id={"episodes-modal-season-#{number}"}
                type="button"
                phx-click="select_season"
                phx-value-season={number}
                phx-target={@myself}
                aria-current={to_string(number == @season.season_number)}
                autofocus={number == @season.season_number}
                class={[
                  "flex h-control-sm shrink-0 snap-start items-center rounded-full px-group text-sm font-semibold whitespace-nowrap transition-colors phx-click-loading:cursor-progress phx-click-loading:opacity-60",
                  number == @season.season_number && "bg-surface-selected text-text",
                  number != @season.season_number &&
                    "text-text-muted hover:bg-surface-hover hover:text-text"
                ]}
              >
                {dgettext("contents", "Season %{number}", number: number)}
              </button>
            </.scroll_row>
            <span :if={length(@season_numbers) == 1} class="text-sm font-semibold">
              {dgettext("contents", "Season %{number}", number: @season.season_number)}
            </span>
            <%!-- Its label changes with its state, so it has no aria-pressed. Its circle sits above
          the episodes' ones. --%>
            <.button
              :if={@any_aired?}
              id="episodes-modal-season-watched"
              variant="ghost"
              size="sm"
              phx-click="toggle_season"
              phx-target={@myself}
              title={
                if @season_watched?,
                  do:
                    dgettext("contents", "Mark season %{number} as not watched",
                      number: @season.season_number
                    ),
                  else:
                    dgettext("contents", "Mark season %{number} as watched",
                      number: @season.season_number
                    )
              }
              class="self-end pr-related!"
            >
              {if @season_watched?,
                do: dgettext("contents", "Watched"),
                else: dgettext("contents", "Mark as watched")}
              <:icon position="end">
                <Lucideicons.circle_check :if={@season_watched?} class="text-success" />
                <Lucideicons.circle :if={!@season_watched?} />
              </:icon>
            </.button>
          </div>

          <ol class="flex flex-col">
            <.episode_row
              :for={row <- @rows}
              row={row}
              in_library?={@in_library?}
              locale={@current_user.settings.locale}
              myself={@myself}
            />
          </ol>
        </div>
      </.modal>
    </div>
    """
  end

  attr :row, :map, required: true, doc: "TMDB's `details` and WatchClub's `episode`, or nil"
  attr :in_library?, :boolean, required: true
  attr :locale, :atom, required: true
  attr :myself, :any, required: true

  # Its still, with Play once it's in the Library, its number and name, its length and a word on
  # where it is, its story, and a check to mark it as watched or not once it aired. The still is
  # grey while it isn't out, and when a TV Show in the Library misses it.
  defp episode_row(assigns) do
    %{details: details, episode: episode} = assigns.row
    aired? = aired?(assigns.row)
    playable? = episode != nil and episode.has_media?
    watching? = episode != nil and episode.actor_progress_status == :in_progress

    assigns =
      assign(assigns,
        details: details,
        episode: episode,
        aired?: aired?,
        playable?: playable?,
        watching?: watching?,
        runtime: Time.minutes(details.runtime, assigns.locale),
        watched?: watched?(episode),
        note:
          cond do
            !aired? and details.air_date == nil ->
              dgettext("contents", "Not out yet")

            !aired? ->
              dgettext("contents", "Out on %{date}",
                date: Time.long_date(details.air_date, assigns.locale)
              )

            assigns.in_library? and !playable? ->
              dgettext("contents", "Not in the library yet")

            watching? ->
              dgettext("contents", "You're watching it")

            true ->
              nil
          end
      )

    ~H"""
    <li id={"episode-#{@details.episode_number}"} class="flex items-start gap-group py-related">
      <.tmdb_still
        size="w300"
        path={@details.still_path}
        class={[
          "w-28 shrink-0 rounded-control @md:w-40",
          (!@aired? or (@in_library? and !@playable?)) && "opacity-60 grayscale"
        ]}
      >
        <span :if={@playable?} class="absolute inset-0 flex items-center justify-center">
          <.button
            id={"episode-#{@details.episode_number}-play"}
            variant="primary"
            size="icon"
            href={Url.player_link(@episode)}
            aria-label={
              dgettext("contents", "Play episode %{number}", number: @details.episode_number)
            }
            title={dgettext("contents", "Play episode %{number}", number: @details.episode_number)}
            class="rounded-full! shadow-overlay"
          >
            <Lucideicons.play class="size-icon-sm" />
          </.button>
        </span>
        <.progress_bar
          :if={@watching?}
          percent={@episode.actor_progress.percent_watched}
          class="absolute inset-x-0 bottom-0 rounded-none!"
        />
      </.tmdb_still>
      <div class="flex min-w-0 flex-1 flex-col gap-tight">
        <span>
          <span class="font-semibold">
            {TvShowEpisode.format_number(@details.season_number, @details.episode_number)}
          </span>
          · {@details.name}
        </span>
        <span class="flex flex-wrap gap-x-related text-xs text-text-muted">
          <span :if={@runtime}>{@runtime}</span>
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
        id={"episode-#{@details.episode_number}-watched"}
        variant="ghost"
        size="icon"
        phx-click="toggle_episode"
        phx-value-episode={@details.episode_number}
        phx-target={@myself}
        aria-pressed={to_string(@watched?)}
        aria-label={
          dgettext("contents", "Watched episode %{number}", number: @details.episode_number)
        }
        title={
          if @watched?,
            do: dgettext("contents", "Mark as not watched"),
            else: dgettext("contents", "Mark as watched")
        }
        class="shrink-0"
      >
        <Lucideicons.circle_check :if={@watched?} class="text-success" />
        <Lucideicons.circle :if={!@watched?} />
      </.button>
      <span :if={!@aired?} class="size-control-md shrink-0"></span>
    </li>
    """
  end

  @impl true
  def update(%{reload_episodes: true}, socket) do
    {:ok,
     assign(socket, :episodes, episodes!(socket.assigns, socket.assigns.season.season_number))}
  end

  # Only the first update loads: the page's later ones change nothing the season shows
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:season, &season!(&1, &1.initial_season))
     |> assign_new(:episodes, &episodes!(&1, &1.initial_season))}
  end

  @impl true
  def handle_event("select_season", %{"season" => season}, socket) do
    season_number = String.to_integer(season)

    {:noreply,
     assign(socket,
       season: season!(socket.assigns, season_number),
       episodes: episodes!(socket.assigns, season_number)
     )}
  end

  def handle_event("toggle_episode", %{"episode" => number}, socket) do
    %{season: season, episodes: episodes} = socket.assigns
    number = String.to_integer(number)

    mark!(
      socket,
      %{season_number: season.season_number, episode_number: number},
      watched?(Map.get(episodes, number))
    )

    {:noreply, socket}
  end

  def handle_event("toggle_season", _params, socket) do
    %{season: season, episodes: episodes} = socket.assigns
    mark!(socket, %{season_number: season.season_number}, season_watched?(rows(season, episodes)))
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

  # TMDB's season, with its episodes' names, stills and air dates
  defp season!(assigns, season_number) do
    assigns.content_identity.external_id
    |> String.to_integer()
    |> Contents.get_tv_show_season_details!(season_number, actor: assigns.current_user)
  end

  # WatchClub's episodes of the season, by number, with their Media and the User's Watch Progress
  defp episodes!(assigns, season_number) do
    assigns.content_identity.external_id
    |> String.to_integer()
    |> Contents.get_episodes_for_show!(
      query: [filter: [season_number: season_number]],
      load: [:has_media?, :videos, :actor_progress_status, :actor_progress],
      actor: assigns.current_user
    )
    |> Map.new(&{&1.episode_number, &1})
  end

  # TMDB's episodes of the season, each with WatchClub's, or nil
  defp rows(season, episodes) do
    for details <- season.episodes,
        do: %{details: details, episode: Map.get(episodes, details.episode_number)}
  end

  # TvShowEpisode.aired?, from TMDB's air date: WatchClub may not have the episode
  defp aired?(%{details: %{air_date: date}}),
    do: date != nil and Date.compare(date, Date.utc_today()) != :gt

  defp watched?(episode), do: episode != nil and episode.actor_progress_status == :completed

  defp season_watched?(rows) do
    aired = Enum.filter(rows, &aired?/1)
    aired != [] and Enum.all?(aired, &watched?(&1.episode))
  end
end
