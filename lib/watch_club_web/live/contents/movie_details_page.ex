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
    AddToListModalLive,
    ContentWatchProgressBadge,
    PlayOrRequestButtonLive
  }

  alias WatchClubWeb.Live.Contents.Components.InYourClubsSectionLive

  @impl true
  def render(%{movie: %MovieDetailsResponse{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      class="p-0!"
      space="none"
    >
      <.movie_details
        movie={@movie}
        content_identity={@content_identity}
        current_user={@current_user}
        selected_club_id={@selected_club_id}
      />

      <.live_component
        :if={@add_to_list_modal_open}
        id="movie-details-add-to-list-modal"
        module={AddToListModalLive}
        content_identity={@content_identity}
        content_title={@movie.title}
        current_user={@current_user}
        on_close={fn -> send(self(), "close_add_to_list_modal") end}
      />
    </Layouts.app>
    """
  end

  attr :content_identity, ContentIdentity, required: true
  attr :movie, MovieDetailsResponse, required: true
  attr :current_user, User, required: true
  attr :selected_club_id, :string, required: true

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
            <.live_component
              :if={@current_user.memberships != []}
              id={InYourClubsSectionLive.dom_id()}
              module={InYourClubsSectionLive}
              current_user={@current_user}
              content_identity={@content_identity}
              content_title={@movie.title}
              selected_club_id={@selected_club_id}
            />
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
    {:ok, socket |> WatchClub.PubSub.subscribe_to_current_user_content_topics() |> reset_modals()}
  end

  @impl true
  def handle_params(%{"tmdb_id" => tmdb_id} = params, _uri, socket) do
    case Integer.parse(tmdb_id) do
      {parsed_id, ""} ->
        content_identity = ContentIdentity.for_movie(parsed_id)

        {:noreply,
         socket
         |> assign(content_identity: content_identity)
         |> load_movie_details(parsed_id)
         |> WatchClub.PubSub.subscribe_to_content_activity_feed(content_identity)
         |> assign(selected_club_id: params["selected_club_id"])}

      _ ->
        {:noreply, socket |> redirect_home}
    end
  end

  # Avoid re-loading the entire movie when it didn't change
  # This happens for example when switching the selected_club_id
  defp load_movie_details(socket, tmdb_id) when socket.assigns.movie.id == tmdb_id, do: socket

  defp load_movie_details(socket, tmdb_id) do
    case Contents.get_movie_details(tmdb_id, actor: socket.assigns.current_user) do
      {:ok, movie} ->
        socket |> assign(movie: movie)

      {:error, _error} ->
        socket |> redirect_home()
    end
  end

  defp redirect_home(socket) do
    socket
    |> put_flash(
      :error,
      dgettext("contents", "The movie you were looking for does not exist")
    )
    |> push_navigate(to: ~p"/")
  end

  @impl true
  def handle_event("open_add_to_list_modal", _params, socket) do
    {:noreply, socket |> assign(:add_to_list_modal_open, true)}
  end

  @impl true
  def handle_info("close_add_to_list_modal", socket) do
    {:noreply, socket |> reset_modals()}
  end

  def handle_info(message, socket) do
    # Send updates to all the Live Components we are using on this page
    InYourClubsSectionLive.handle_pubsub_message(message, socket.assigns.content_identity)
    ContentWatchProgressBadge.handle_pubsub_message(message, socket.assigns.current_user)
    PlayOrRequestButtonLive.handle_pubsub_message(message, socket.assigns.current_user)

    {:noreply, socket}
  end

  defp reset_modals(socket) do
    socket |> assign(add_to_list_modal_open: false)
  end
end
