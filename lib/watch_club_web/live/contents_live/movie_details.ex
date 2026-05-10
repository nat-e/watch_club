defmodule WatchClubWeb.ContentsLive.MovieDetails do
  use WatchClubWeb, :live_view

  require Logger

  alias WatchClub.Contents.ContentView
  alias WatchClub.Integrations.Tmdb.MovieDetailsResponse
  alias WatchClubWeb.LiveComponents.ClubSelectionButton

  @impl true
  def render(%{movie: %ContentView{details: %MovieDetailsResponse{}}} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}>
      <:backdrop :if={@movie.details.backdrop_path}>
        <.tmdb_backdrop
          size="w1280"
          class="h-full w-full object-cover"
          path={@movie.details.backdrop_path}
        />
      </:backdrop>
      <div class="flex flex-col items-center gap-2">
        <.tmdb_poster
          size="w500"
          path={@movie.details.poster_path}
          class="mb-4 w-46 rounded-md shadow-lg"
        />
        <h1 class="text-xl font-semibold xl:text-3xl">
          {@movie.title}
          <span :if={@movie.details.release_date.year}>({@movie.details.release_date.year})</span>
        </h1>

        <div class="flex flex-row items-center justify-center text-sm text-gray-400 divide-x">
          <span :if={@movie.details.runtime} class="px-2">{@movie.details.runtime} minutes</span>
          <span :for={genre <- @movie.details.genres} class="px-2">{genre.name}</span>
        </div>

        <div class="relative mt-4 flex shrink-0 flex-wrap items-center justify-center gap-2 xl:mt-0 xl:flex-nowrap">
          <.live_component
            id="club_selection_button"
            module={ClubSelectionButton}
            content={@movie}
            current_user={@current_user}
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}></Layouts.app>
    """
  end

  @impl true
  @spec mount(map(), any(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"tmdb_id" => tmdb_id}, _session, socket) do
    user = socket.assigns.current_user

    case Contents.get_movie_details(tmdb_id, actor: user) do
      {:ok, movie} ->
        {:ok, socket |> assign(:movie, movie)}

      {:error, error} ->
        Logger.warning("Error loading movie: #{inspect(error)}")
        {:ok, socket}
    end
  end
end
