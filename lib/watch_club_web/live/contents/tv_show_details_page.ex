defmodule WatchClubWeb.Contents.TvShowDetailsPage do
  use WatchClubWeb, :live_view

  require Logger

  import WatchClubWeb.Components.Contents.Details.DetailsBackdrop
  import WatchClubWeb.Components.Contents.Details.HeroPanel
  import WatchClubWeb.Components.Contents.Details.ReviewsCard
  import WatchClubWeb.Components.Contents.Details.ExternalLinksCard
  import WatchClubWeb.Components.Contents.Details.CastSection
  import WatchClubWeb.Contents.TvShowDetailsPage.EpisodesSection

  alias WatchClub.Contents.ContentView
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse

  @impl true
  def render(%{tv_show: %ContentView{details: %TvDetailsResponse{}}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      class="p-0!"
      space="none"
    >
      <.tv_show_details
        tv_show={@tv_show}
        current_user={@current_user}
        selected_season={@selected_season}
        season_metadata_by_number={@season_metadata_by_number}
      />
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

  attr :tv_show, ContentView, required: true
  attr :current_user, User, required: true
  attr :selected_season, :integer, required: true
  attr :season_metadata_by_number, :map, required: true

  defp tv_show_details(assigns) do
    ~H"""
    <article
      aria-labelledby="content-details-title"
      class="relative min-h-[calc(100svh-var(--wc-size-row-lg))] overflow-hidden bg-canvas"
    >
      <.details_backdrop path={@tv_show.details.backdrop_path} />

      <div class="relative z-1 mx-auto flex w-full max-w-[100rem] flex-col gap-cluster px-page pb-page-y pt-section @container">
        <.hero_panel content={@tv_show} current_user={@current_user} />

        <div class="flex flex-col gap-cluster @6xl:flex-row @6xl:items-start">
          <div class="flex min-w-0 flex-1 flex-col gap-cluster">
            <.section
              :if={@tv_show.details.overview}
              title={dgettext("contents", "Overview")}
              icon={:tv}
            >
              <p class="leading-7 text-text-muted">
                {@tv_show.details.overview}
              </p>
            </.section>

            <.episodes_section
              :if={season_summaries(@tv_show.details) != []}
              content={@tv_show}
              details={@tv_show.details}
              selected_season={@selected_season}
              season_metadata_by_number={@season_metadata_by_number}
              current_user={@current_user}
            />

            <.cast_section content={@tv_show} />
          </div>

          <aside
            aria-label={"#{dgettext("contents", "Reviews")} / #{dgettext("contents", "External links")}"}
            class="flex w-full flex-col gap-cluster @6xl:w-[22rem] @6xl:shrink-0"
          >
            <.reviews_card content={@tv_show} current_user={@current_user} />
            <.external_links_card content={@tv_show} />
          </aside>
        </div>
      </div>
    </article>
    """
  end

  @impl true
  def mount(%{"tmdb_id" => tmdb_id}, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        WatchClub.PubSub,
        WatchClub.PubSub.content_topic(:tmdb, tmdb_id)
      )

      Phoenix.PubSub.subscribe(
        WatchClub.PubSub,
        WatchClub.PubSub.content_view_topic(:tmdb, tmdb_id, user.id)
      )
    end

    case load_tv_show(tmdb_id, user) do
      {:ok, tv_show} ->
        season_summaries = season_summaries(tv_show.details)

        socket =
          socket
          |> assign(:tv_show, tv_show)
          |> assign(:selected_season, default_season(tv_show))
          |> assign(
            :season_metadata_by_number,
            initial_season_metadata_by_number(season_summaries)
          )
          |> start_season_metadata_loads(season_summaries)

        {:ok, socket}

      {:error, error} ->
        Logger.warning("Error loading TV Show: #{inspect(error)}")
        {:ok, socket}
    end
  end

  @impl true
  def handle_info({:content_libraries_updated, %ContentView{} = tv_show}, socket) do
    {:noreply, assign(socket, :tv_show, tv_show)}
  end

  def handle_info(
        %Ash.Notifier.Notification{
          metadata: %{subject: :content_changed, external_id: tmdb_id}
        },
        socket
      ) do
    case load_tv_show(tmdb_id, socket.assigns.current_user) do
      {:ok, show} ->
        {:noreply, socket |> assign(:tv_show, show)}

      {:error, error} ->
        Logger.error("Error reloading TV show: #{inspect(error)}")
        {:noreply, socket}
    end
  end

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

  defp load_tv_show(tmdb_id, user) do
    Contents.get_tv_show_details(tmdb_id, actor: user)
  end

  defp initial_season_metadata_by_number(season_summaries) do
    Map.new(season_summaries, fn season -> {season.season_number, %{status: :loading}} end)
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
    tmdb_id = socket.assigns.tv_show.external_id
    actor = socket.assigns.current_user

    start_async(socket, {:season_metadata, season_number}, fn ->
      Contents.get_tv_show_season_details(tmdb_id, season_number, actor: actor)
    end)
  end

  defp default_season(%ContentView{details: %TvDetailsResponse{} = details}) do
    case season_summaries(details) do
      [season | _] -> season.season_number
      [] -> 1
    end
  end

  defp default_season(_), do: 1

  defp season_summaries(%TvDetailsResponse{} = details) do
    details.seasons
    |> Enum.filter(&(&1.season_number >= 1 and &1.episode_count > 0))
    |> Enum.sort_by(& &1.season_number)
  end
end
