defmodule WatchClubWeb.Contents.MovieDetailsPage do
  use WatchClubWeb, :live_view

  require Logger

  import WatchClubWeb.Components.Contents.TmdbBackdrop
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
      <.tmdb_backdrop
        :if={@movie.details.backdrop_path}
        path={@movie.details.backdrop_path}
        size="w1280"
        alt=""
        aria-hidden="true"
        class="absolute inset-0 h-full w-full object-cover opacity-35"
      />
      <div
        aria-hidden="true"
        class="absolute inset-0 bg-linear-to-r from-canvas via-canvas/82 to-canvas/45"
      >
      </div>
      <div
        aria-hidden="true"
        class="absolute inset-0 bg-linear-to-b from-canvas/10 via-canvas/82 to-canvas"
      >
      </div>
      <div
        aria-hidden="true"
        class="absolute inset-0 bg-[radial-gradient(circle_at_28%_18%,var(--wc-color-primary-bg),transparent_34rem)]"
      >
      </div>

      <div class="relative z-1 mx-auto grid w-full max-w-[100rem] grid-cols-1 gap-cluster px-page pb-page-y pt-section 2xl:grid-cols-[minmax(0,1fr)_22rem] 2xl:items-start">
        <.hero_panel content={@movie} current_user={@current_user} />

        <div class="grid gap-cluster">
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
          class="grid content-start gap-cluster"
        >
          <.reviews_card content={@movie} current_user={@current_user} />
          <.external_links_card content={@movie} />
        </aside>
      </div>
    </article>
    """
  end

  @impl true
  @spec mount(map(), any(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"tmdb_id" => tmdb_id}, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
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

  @impl true
  def handle_info(
        %Ash.Notifier.Notification{
          metadata: %{subject: :content_view_changed, external_id: tmdb_id}
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

  defp load_movie(tmdb_id, user) do
    Contents.get_movie_details(tmdb_id, actor: user)
  end
end
