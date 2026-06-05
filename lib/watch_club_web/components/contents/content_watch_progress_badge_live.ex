defmodule WatchClubWeb.Components.Contents.ContentWatchProgressBadge do
  @moduledoc """
  Badge representing the watch progress status of the current user for a given Content.
  """
  use WatchClubWeb, :live_component

  alias WatchClub.Contents.{Book, ContentView, Movie, TvShow}

  @impl true
  def render(%{status: :completed} = assigns) do
    ~H"""
    <button class="w-fit" phx-target={@myself} phx-click="mark_not_watched">
      <.badge variant="success" size="lg">
        <:icon><Lucideicons.check_circle_2 /></:icon>
        Watched
      </.badge>
    </button>
    """
  end

  def render(assigns) do
    ~H"""
    <button class="w-fit" phx-target={@myself} phx-click="mark_watched">
      <.badge variant="muted" size="lg">
        <:icon><Lucideicons.check_circle_2 /></:icon>
        Mark as watched
      </.badge>
    </button>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:status, ContentView.viewer_progress_status(assigns.content))}
  end

  @impl true
  def handle_event("mark_watched", _params, socket) do
    user = socket.assigns.current_user

    with {:ok, content} <- ContentView.ensure_content_exists(socket.assigns.content, user),
         {:ok, _} <- mark_content_watched(content.content, user) do
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
         {:ok, _} <- mark_content_not_watched(content.content, user) do
      {:noreply, socket}
    else
      {:error, error} ->
        Logger.error("Error marking content not watched #{inspect(error)}")
        {:noreply, socket |> put_flash(:error, "Something wrong happened")}
    end
  end

  defp mark_content_watched(%Content{movie: %Movie{} = movie}, current_user) do
    Contents.mark_movie_watched(movie, actor: current_user)
  end

  defp mark_content_watched(%Content{tv_show: %TvShow{} = show}, current_user) do
    Contents.mark_show_watched(show, actor: current_user)
  end

  defp mark_content_watched(%Content{book: %Book{} = book}, current_user) do
    Contents.mark_book_read(book, actor: current_user)
  end

  defp mark_content_not_watched(%Content{movie: %Movie{} = movie}, current_user) do
    Contents.mark_movie_not_watched(movie, actor: current_user)
  end

  defp mark_content_not_watched(%Content{tv_show: %TvShow{} = show}, current_user) do
    Contents.mark_show_not_watched(show, actor: current_user)
  end

  defp mark_content_not_watched(%Content{book: %Book{} = book}, current_user) do
    Contents.mark_book_not_read(book, actor: current_user)
  end
end
