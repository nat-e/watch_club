defmodule WatchClubWeb.Contents.TvShowDetailsPage do
  use WatchClubWeb, :live_view

  require Logger
  require Ash.Query

  import WatchClubWeb.Components.Contents.Details.{
    CastSection,
    DetailsBackdrop,
    ExternalLinksCard,
    HeroPanel,
    ReviewsCard
  }

  import WatchClubWeb.Contents.TvShowDetailsPage.EpisodesSection

  alias WatchClub.Contents.ContentIdentity
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse

  alias WatchClubWeb.Components.Contents.{
    AddToLibraryButtonLive,
    ContentWatchProgressBadge,
    PlayOrRequestButtonLive
  }

  @impl true
  def render(%{tv_show: %TvDetailsResponse{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      class="p-0!"
      space="none"
    >
      <article
        aria-labelledby="content-details-title"
        class="relative min-h-[calc(100svh-var(--wc-size-row-lg))] overflow-hidden bg-canvas"
      >
        <.details_backdrop path={@tv_show.backdrop_path} />

        <div class="relative z-1 mx-auto flex w-full max-w-[100rem] flex-col gap-cluster px-page pb-page-y pt-section @container">
          <.hero_panel
            content_identity={ContentIdentity.for_tv_show(@tv_show.id)}
            content={@tv_show}
            current_user={@current_user}
          />

          <div class="flex flex-col gap-cluster @6xl:flex-row @6xl:items-start">
            <div class="flex min-w-0 flex-1 flex-col gap-cluster">
              <.section
                :if={@tv_show.overview}
                title={dgettext("contents", "Overview")}
                icon={:tv}
              >
                <p class="leading-7 text-text-muted">
                  {@tv_show.overview}
                </p>
              </.section>

              <.episodes_section
                :if={@tv_show.seasons != []}
                details={@tv_show}
                selected_season={@selected_season}
                season_metadata_by_number={@season_metadata_by_number}
                episodes={@episodes}
                current_user={@current_user}
              />

              <.cast_section credits={@tv_show.credits} />
            </div>

            <aside
              aria-label={"#{dgettext("contents", "Reviews")} / #{dgettext("contents", "External links")}"}
              class="flex w-full flex-col gap-cluster @6xl:w-[22rem] @6xl:shrink-0"
            >
              <.reviews_card
                vote_average={@tv_show.vote_average}
                vote_count={@tv_show.vote_count}
                current_user={@current_user}
              />
              <.external_links_card content={@tv_show} />
            </aside>
          </div>
        </div>
      </article>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}>
      <.empty>
        <:icon><Lucideicons.tv /></:icon>
        <:title>{dgettext("contents", "TV Show unavailable")}</:title>
        <:description>
          {dgettext("contents", "We could not load this TV Show. Try again later.")}
        </:description>
      </.empty>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(%{"tmdb_id" => tmdb_id}, _uri, socket) do
    user = socket.assigns.current_user

    WatchClub.PubSub.subscribe_if_connected(socket, [
      WatchClub.PubSub.content_topic(:tmdb, tmdb_id),
      WatchClub.PubSub.content_view_topic(:tmdb, tmdb_id, user.id)
    ])

    case Integer.parse(tmdb_id) do
      {parsed_id, ""} -> {:noreply, socket |> load_tv_show_details(parsed_id)}
      _ -> {:noreply, socket |> redirect_home()}
    end
  end

  defp load_tv_show_details(socket, tmdb_id) do
    case Contents.get_tv_show_details(tmdb_id, actor: socket.assigns.current_user) do
      {:ok, tv_show} ->
        socket
        |> assign(
          tv_show: tv_show,
          selected_season: 1,
          season_metadata_by_number:
            Map.new(tv_show.seasons, &{&1.season_number, %{status: :loading}})
        )
        |> load_episodes()
        |> start_season_metadata_loads(tv_show.seasons)

      {:error, _} ->
        socket |> redirect_home()
    end
  end

  # Load the TvShowEpisode data from database if they exist with their context
  # (whether they are playable and watched by the current user)
  # They are loaded into the socket assigns, in a 2 levels map indexed by season number
  # and episode number for fast retrieval.
  defp load_episodes(socket) do
    episodes_map =
      Contents.get_episodes_for_show!(socket.assigns.tv_show.id,
        load: [
          # This is used for displaying the watch progress badge at the season and episode level
          :actor_progress_status,
          # has_media? and videos is used to display the play button on each episode
          :has_media?,
          :videos
        ],
        actor: socket.assigns.current_user
      )
      |> Enum.group_by(& &1.season_number)
      |> Map.new(fn {season_number, episodes} ->
        {season_number, Map.new(episodes, &{&1.episode_number, &1})}
      end)

    socket |> assign(episodes: episodes_map)
  end

  defp redirect_home(socket) do
    socket
    |> put_flash(
      :error,
      dgettext("contents", "The TV Show you were looking for does not exist")
    )
    |> push_navigate(to: ~p"/")
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          payload: %Ash.Notifier.Notification{
            metadata: %{subject: :content_changed, content_identity: content_identity}
          }
        },
        socket
      ) do
    # Update all the live components that load their own data
    # This could be optimized
    send_update(ContentWatchProgressBadge,
      id: "content-watch-progress",
      content_identity: content_identity,
      current_user: socket.assigns.current_user
    )

    send_update(PlayOrRequestButtonLive,
      id: "details-play-or-request-button",
      content_identity: content_identity,
      current_user: socket.assigns.current_user
    )

    send_update(AddToLibraryButtonLive,
      id: "details-add-to-library-button",
      content_identity: content_identity,
      current_user: socket.assigns.current_user
    )

    # Reload the episode data
    {:noreply, socket |> load_episodes()}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def handle_async({:season_metadata, season_number}, {:ok, {:ok, season_details}}, socket) do
    {:noreply,
     socket
     |> finish_season_metadata_load(season_number, %{status: :loaded, details: season_details})}
  end

  def handle_async({:season_metadata, season_number}, {:ok, {:error, error}}, socket) do
    Logger.warning("Error loading TV Show season metadata: #{inspect(error)}")

    {:noreply,
     socket
     |> finish_season_metadata_load(season_number, %{status: :failed, error: error})}
  end

  def handle_async({:season_metadata, season_number}, {:exit, reason}, socket) do
    Logger.warning("Error loading TV Show season metadata: #{inspect(reason)}")

    {:noreply,
     socket
     |> finish_season_metadata_load(season_number, %{status: :failed, error: reason})}
  end

  @impl true
  def handle_event("select_season", %{"season" => season}, socket) do
    {:noreply, assign(socket, :selected_season, String.to_integer(season))}
  end

  def handle_event("retry_season_metadata", %{"season" => season}, socket) do
    season_number = String.to_integer(season)

    {:noreply,
     socket
     |> put_season_metadata(season_number, %{status: :loading})
     |> start_season_metadata_load(season_number)}
  end

  defp finish_season_metadata_load(socket, season_number, metadata) do
    put_season_metadata(socket, season_number, metadata)
  end

  defp put_season_metadata(socket, season_number, metadata) do
    update(socket, :season_metadata_by_number, &Map.put(&1, season_number, metadata))
  end

  defp start_season_metadata_loads(socket, season_summaries) do
    Enum.reduce(season_summaries, socket, fn season, socket ->
      start_season_metadata_load(socket, season.season_number)
    end)
  end

  defp start_season_metadata_load(socket, season_number) do
    tmdb_id = socket.assigns.tv_show.id
    actor = socket.assigns.current_user

    start_async(socket, {:season_metadata, season_number}, fn ->
      Contents.get_tv_show_season_details(tmdb_id, season_number, actor: actor)
    end)
  end
end
