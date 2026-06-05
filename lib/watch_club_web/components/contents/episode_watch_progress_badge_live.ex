defmodule WatchClubWeb.Components.Contents.EpisodeWatchProgressBadge do
  @moduledoc """
  Badge representing the watch progress status of the current user for a given TvShowEpisode
  """
  use WatchClubWeb, :live_component

  alias WatchClub.Contents.ContentView

  @impl true
  def render(%{status: :completed} = assigns) do
    ~H"""
    <button class="w-fit" phx-target={@myself} phx-click="mark_not_watched">
      <.badge variant="success">
        <:icon><Lucideicons.check_circle_2 /></:icon>
        Watched
      </.badge>
    </button>
    """
  end

  def render(assigns) do
    ~H"""
    <button class="w-fit" phx-target={@myself} phx-click="mark_watched">
      <.badge variant="muted">
        <:icon><Lucideicons.check_circle_2 /></:icon>
        Mark as watched
      </.badge>
    </button>
    """
  end

  @impl true
  def update(assigns, socket) do
    episode = ContentView.episode(assigns.content, assigns.season_number, assigns.episode_number)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       :status,
       (episode && episode.viewer_progress_status) || :not_started
     )}
  end

  @impl true
  def handle_event("mark_watched", _params, socket) do
    user = socket.assigns.current_user

    with {:ok, content} <- ContentView.ensure_content_exists(socket.assigns.content, user),
         {:ok, _} <-
           Contents.mark_show_episode_watched(
             content.content.tv_show,
             %{
               season_number: socket.assigns.season_number,
               episode_number: socket.assigns.episode_number
             },
             actor: user
           ) do
      {:noreply, socket}
    else
      {:error, error} ->
        Logger.error("Error marking content watched #{inspect(error)}")
        {:noreply, socket |> put_flash(:error, "Something wrong happened")}
    end
  end

  def handle_event("mark_not_watched", _params, socket) do
    user = socket.assigns.current_user

    with {:ok, content} <- ContentView.ensure_content_exists(socket.assigns.content, user),
         {:ok, _} <-
           Contents.mark_show_episode_not_watched(
             content.content.tv_show,
             %{
               season_number: socket.assigns.season_number,
               episode_number: socket.assigns.episode_number
             },
             actor: user
           ) do
      {:noreply, socket}
    else
      {:error, error} ->
        Logger.error("Error marking content not watched #{inspect(error)}")
        {:noreply, socket |> put_flash(:error, "Something wrong happened")}
    end
  end
end
