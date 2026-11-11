defmodule WatchClubWeb.Contents.ContentPage.EpisodesModalLive do
  @moduledoc """
  Every persisted TV Show Episode of a TV Show, one season at a time, in a big modal, full screen on
  phones. Each aired episode has a check that marks it as watched or not, and Play and Download once
  it's in the Library. The season has a check too.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Medias.DownloadMenu

  @doc """
  The DOM id of the modal, which shows at most once on a page.
  """
  def dom_id, do: "episodes"

  @doc """
  Reloads persisted episode metadata, Media, and the User's Watch Progress when Content changes.
  """
  def reload_episodes, do: send_update(__MODULE__, id: dom_id(), reload_episodes?: true)

  attr :content_identity, ContentIdentity, required: true
  attr :title, :string, required: true, doc: "the TV Show's name"
  attr :season_numbers, :list, required: true
  attr :initial_season, :integer, required: true, doc: "the season it opens on"
  attr :in_library?, :boolean, required: true
  attr :current_user, User, required: true
  attr :on_close, JS, required: true

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        any_aired?: Enum.any?(assigns.episodes, & &1.aired?),
        season_watched?: season_watched?(assigns.episodes)
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
            do: dgettext("contents", "Play or download any episode, and mark what you've watched."),
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
              <.pill
                :for={number <- @season_numbers}
                id={"episodes-modal-season-#{number}"}
                current={number == @season}
                phx-click="select_season"
                phx-value-season={number}
                phx-target={@myself}
                autofocus={number == @season}
              >
                {dgettext("contents", "Season %{number}", number: number)}
              </.pill>
            </.scroll_row>
            <span :if={length(@season_numbers) == 1} class="text-sm font-semibold">
              {dgettext("contents", "Season %{number}", number: @season)}
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
                  do: dgettext("contents", "Mark season %{number} as not watched", number: @season),
                  else: dgettext("contents", "Mark season %{number} as watched", number: @season)
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
              :for={episode <- @episodes}
              episode={episode}
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

  attr :episode, TvShowEpisode, required: true
  attr :in_library?, :boolean, required: true
  attr :locale, :atom, required: true
  attr :myself, :any, required: true

  # Its still, with Play once it's in the Library, its number and name, its length, its Parts when it
  # has several, the episodes its file also holds and a word on where it is, its story, and a check
  # to mark it as watched or not once it aired, with Download under it once it's in the Library.
  # The still is grey while it isn't out, and when a TV Show in the Library misses it.
  defp episode_row(assigns) do
    episode = assigns.episode
    localization = episode.best_localization || %{title: nil, overview: nil}
    aired? = episode.aired?
    playable? = episode.has_media?
    watching? = episode.actor_progress_status == :in_progress

    shares_file_with =
      for part <- episode.parts,
          video <- part.videos,
          %{tv_show_episode: %TvShowEpisode{} = other} <- video.parts,
          other.id != episode.id,
          uniq: true,
          do: TvShowEpisode.format_number(other.season_number, other.episode_number)

    assigns =
      assign(assigns,
        localization: localization,
        aired?: aired?,
        playable?: playable?,
        watching?: watching?,
        runtime: Time.minutes(episode.runtime, assigns.locale),
        shares_file_with: shares_file_with,
        watched?: episode.actor_progress_status == :completed,
        note:
          cond do
            !aired? and episode.air_date == nil ->
              dgettext("contents", "Not out yet")

            !aired? ->
              dgettext("contents", "Out on %{date}",
                date: Time.long_date(episode.air_date, assigns.locale)
              )

            assigns.in_library? and !playable? ->
              dgettext("contents", "Not in the library yet")

            true ->
              nil
          end
      )

    ~H"""
    <li id={"episode-#{@episode.episode_number}"} class="flex items-start gap-group py-related">
      <.tmdb_still
        size="w300"
        path={@episode.still_path}
        class={[
          "w-28 shrink-0 rounded-control @md:w-40",
          (!@aired? or (@in_library? and !@playable?)) && "opacity-60 grayscale"
        ]}
      >
        <span :if={@playable?} class="absolute inset-0 flex items-center justify-center">
          <.button
            id={"episode-#{@episode.episode_number}-play"}
            variant="primary"
            size="icon"
            href={Url.player_link(@episode.actor_video_to_play)}
            aria-label={
              dgettext("contents", "Play episode %{number}", number: @episode.episode_number)
            }
            title={dgettext("contents", "Play episode %{number}", number: @episode.episode_number)}
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
            {TvShowEpisode.format_number(@episode.season_number, @episode.episode_number)}
          </span>
          <span :if={@localization.title}>· {@localization.title}</span>
        </span>
        <span class="flex flex-wrap gap-x-related text-xs text-text-muted">
          <span :if={@runtime}>{@runtime}</span>
          <span :if={length(@episode.parts) > 1}>
            {dngettext("contents", "%{count} part", "%{count} parts", length(@episode.parts))}
          </span>
          <span :if={@shares_file_with != []}>
            {dgettext("contents", "Same file as %{episodes}",
              episodes: Enum.join(@shares_file_with, ", ")
            )}
          </span>
          <span :if={@note} class="font-semibold">{@note}</span>
        </span>
        <span
          :if={@localization.overview not in [nil, ""]}
          class="line-clamp-2 max-w-readable text-sm text-text-muted"
        >
          {@localization.overview}
        </span>
      </div>
      <div class="flex shrink-0 flex-col">
        <.button
          :if={@aired?}
          id={"episode-#{@episode.episode_number}-watched"}
          variant="ghost"
          size="icon"
          phx-click="toggle_episode"
          phx-value-episode={@episode.episode_number}
          phx-target={@myself}
          aria-pressed={to_string(@watched?)}
          aria-label={
            dgettext("contents", "Watched episode %{number}", number: @episode.episode_number)
          }
          title={
            if @watched?,
              do: dgettext("contents", "Mark as not watched"),
              else: dgettext("contents", "Mark as watched")
          }
        >
          <Lucideicons.circle_check :if={@watched?} class="text-success" />
          <Lucideicons.circle :if={!@watched?} />
        </.button>
        <span :if={!@aired?} class="size-control-md"></span>
        <.download_menu
          :if={@playable?}
          id={"episode-#{@episode.episode_number}-download"}
          parts={@episode.parts}
        >
          <:trigger :let={download_link}>
            <.button
              id={"episode-#{@episode.episode_number}-download-button"}
              variant="ghost"
              size="icon"
              aria-label={
                dgettext("contents", "Download episode %{number}", number: @episode.episode_number)
              }
              title={
                dgettext("contents", "Download episode %{number}", number: @episode.episode_number)
              }
              {download_link}
            >
              <Lucideicons.download />
            </.button>
          </:trigger>
        </.download_menu>
      </div>
    </li>
    """
  end

  @impl true
  def update(%{reload_episodes?: true} = assigns, socket) do
    socket = assign(socket, Map.delete(assigns, :reload_episodes?))

    season_number =
      if socket.assigns.season in socket.assigns.season_numbers,
        do: socket.assigns.season,
        else: socket.assigns.initial_season

    {:ok,
     assign(socket, season: season_number, episodes: episodes!(socket.assigns, season_number))}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:season, & &1.initial_season)
     |> assign_new(:episodes, &episodes!(&1, &1.initial_season))}
  end

  @impl true
  def handle_event("select_season", %{"season" => season}, socket) do
    season_number = String.to_integer(season)

    {:noreply,
     assign(socket,
       season: season_number,
       episodes: episodes!(socket.assigns, season_number)
     )}
  end

  def handle_event("toggle_episode", %{"episode" => number}, socket) do
    %{season: season, episodes: episodes} = socket.assigns
    number = String.to_integer(number)

    mark!(
      socket,
      %{season_number: season, episode_number: number},
      Enum.find(episodes, &(&1.episode_number == number)).actor_progress_status == :completed
    )

    {:noreply, socket}
  end

  def handle_event("toggle_season", _params, socket) do
    %{season: season, episodes: episodes} = socket.assigns
    mark!(socket, %{season_number: season}, season_watched?(episodes))
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

  # The persisted episodes of the selected season, with metadata and watch state.
  defp episodes!(assigns, season_number) do
    assigns.content_identity.external_id
    |> String.to_integer()
    |> Contents.get_episodes_for_show!(
      query: [filter: [season_number: season_number]],
      load: [
        :best_localization,
        :aired?,
        :has_media?,
        :actor_progress_status,
        :actor_progress,
        :actor_video_to_play,
        parts: [videos: [:media, :default_video_track, parts: :tv_show_episode]]
      ],
      actor: assigns.current_user
    )
  end

  defp season_watched?(episodes) do
    aired = Enum.filter(episodes, & &1.aired?)
    aired != [] and Enum.all?(aired, &(&1.actor_progress_status == :completed))
  end
end
