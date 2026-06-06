defmodule WatchClubWeb.Contents.MovieDetailsPage do
  use WatchClubWeb, :live_view

  require Logger

  import WatchClubWeb.Components.Contents.Details.DetailsBackdrop
  import WatchClubWeb.Components.Contents.Details.HeroPanel
  import WatchClubWeb.Components.Contents.Details.ReviewsCard
  import WatchClubWeb.Components.Contents.Details.ExternalLinksCard
  import WatchClubWeb.Components.Contents.Details.CastSection

  alias WatchClub.Contents.ContentView
  alias WatchClub.Integrations.Tmdb.MovieDetailsResponse

  @impl true
  def render(%{movie: %ContentView{details: %MovieDetailsResponse{}}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      class="p-0!"
      space="none"
    >
      <.movie_details movie={@movie} current_user={@current_user} />
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}>
      <.empty>
        <:icon><Lucideicons.film /></:icon>
        <:title>{dgettext("contents", "Movie unavailable")}</:title>
        <:description>
          {dgettext("contents", "We could not load this movie. Try again later.")}
        </:description>
      </.empty>
    </Layouts.app>
    """
  end

  attr :movie, ContentView, required: true
  attr :current_user, User, required: true

  defp movie_details(assigns) do
    ~H"""
    <article
      aria-labelledby="content-details-title"
      class="relative min-h-[calc(100svh-var(--wc-size-row-lg))] overflow-hidden bg-canvas"
    >
      <.details_backdrop path={@movie.details.backdrop_path} />

      <div class="relative z-1 mx-auto flex w-full max-w-[100rem] flex-col gap-cluster px-page pb-page-y pt-section @container">
        <.hero_panel content={@movie} current_user={@current_user} />

        <div class="flex flex-col gap-cluster @6xl:flex-row @6xl:items-start">
          <div class="flex min-w-0 flex-1 flex-col gap-cluster">
            <.section
              :if={@movie.details.overview}
              title={dgettext("contents", "Overview")}
              icon={:film}
            >
              <p class="leading-7 text-text-muted">
                {@movie.details.overview}
              </p>
            </.section>

            <.cast_section content={@movie} />
          </div>

          <aside
            aria-label={"#{dgettext("contents", "Reviews")} / #{dgettext("contents", "External links")}"}
            class="flex w-full flex-col gap-cluster @6xl:w-[22rem] @6xl:shrink-0"
          >
            <.reviews_card content={@movie} current_user={@current_user} />
            <.external_links_card content={@movie} />
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

    case load_movie(tmdb_id, user) do
      {:ok, movie} ->
        {:ok, socket |> assign(:movie, movie)}

      {:error, error} ->
        Logger.warning("Error loading movie: #{inspect(error)}")
        {:ok, socket}
    end
  end

  @impl true
  def handle_info({:content_libraries_updated, %ContentView{} = movie}, socket) do
    {:noreply, assign(socket, :movie, movie)}
  end

  def handle_info(
        %Ash.Notifier.Notification{
          metadata: %{subject: :content_changed, external_id: tmdb_id}
        },
        socket
      ) do
    case load_movie(tmdb_id, socket.assigns.current_user) do
      {:ok, movie} ->
        {:noreply, socket |> assign(:movie, movie)}

      {:error, error} ->
        Logger.error("Error reloading movie: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp load_movie(tmdb_id, user) do
    Contents.get_movie_details(tmdb_id, actor: user)
  end
end
