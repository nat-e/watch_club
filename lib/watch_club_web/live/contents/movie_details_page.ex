defmodule WatchClubWeb.Contents.MovieDetailsPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.Details.{
    CastSection,
    DetailsBackdrop,
    ExternalLinksCard,
    HeroPanel,
    ReviewsCard
  }

  alias WatchClub.Integrations.Tmdb.MovieDetailsResponse

  alias WatchClubWeb.Components.Contents.{
    AddToLibraryButtonLive,
    ContentWatchProgressBadge,
    PlayOrRequestButtonLive
  }

  @impl true
  def render(%{movie: %MovieDetailsResponse{}} = assigns) do
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

  attr :movie, MovieDetailsResponse, required: true
  attr :current_user, User, required: true

  defp movie_details(assigns) do
    ~H"""
    <article
      aria-labelledby="content-details-title"
      class="relative min-h-[calc(100svh-var(--wc-size-row-lg))] overflow-hidden bg-canvas"
    >
      <.details_backdrop path={@movie.backdrop_path} />

      <div class="relative z-1 mx-auto flex w-full max-w-[100rem] flex-col gap-cluster px-page pb-page-y pt-section @container">
        <.hero_panel
          content_identity={ContentIdentity.for_movie(@movie.id)}
          content={@movie}
          current_user={@current_user}
        />

        <div class="flex flex-col gap-cluster @6xl:flex-row @6xl:items-start">
          <div class="flex min-w-0 flex-1 flex-col gap-cluster">
            <.section
              :if={@movie.overview}
              title={dgettext("contents", "Overview")}
              icon={:film}
            >
              <p class="leading-7 text-text-muted">
                {@movie.overview}
              </p>
            </.section>

            <.cast_section credits={@movie.credits} />
          </div>

          <aside
            aria-label={"#{dgettext("contents", "Reviews")} / #{dgettext("contents", "External links")}"}
            class="flex w-full flex-col gap-cluster @6xl:w-[22rem] @6xl:shrink-0"
          >
            <.reviews_card
              vote_average={@movie.vote_average}
              vote_count={@movie.vote_count}
              current_user={@current_user}
            />
            <.external_links_card content={@movie} />
          </aside>
        </div>
      </div>
    </article>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> WatchClub.PubSub.subscribe_to_current_user_content_topics()}
  end

  @impl true
  def handle_params(%{"tmdb_id" => tmdb_id}, _uri, socket) do
    with {parsed_id, ""} <- Integer.parse(tmdb_id),
         {:ok, movie} <- Contents.get_movie_details(parsed_id, actor: socket.assigns.current_user) do
      {:noreply, socket |> assign(:movie, movie)}
    else
      _ ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           dgettext("contents", "The movie you were looking for does not exist")
         )
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_info(message, socket) do
    # Send updates to all the Live Components we are using on the request cards
    AddToLibraryButtonLive.handle_pubsub_message(message, socket.assigns.current_user)
    ContentWatchProgressBadge.handle_pubsub_message(message, socket.assigns.current_user)
    PlayOrRequestButtonLive.handle_pubsub_message(message, socket.assigns.current_user)

    {:noreply, socket}
  end
end
