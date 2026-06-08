defmodule WatchClubWeb.Components.Contents.ContentWatchProgressBadge do
  @moduledoc """
  Badge representing the watch progress status of the current user for a given Content.
  """
  use WatchClubWeb, :live_component

  alias WatchClub.Contents.ContentView

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
    case History.mark_content_watched(ContentView.identity(socket.assigns.content),
           actor: socket.assigns.current_user
         ) do
      {:ok, _content} ->
        {:noreply, socket}

      {:error, error} ->
        Logger.error("Error marking content watched #{inspect(error)}")
        {:noreply, socket |> put_flash(:error, "Something wrong happened")}
    end
  end

  def handle_event("mark_not_watched", _params, socket) do
    case History.mark_content_not_watched(ContentView.identity(socket.assigns.content),
           actor: socket.assigns.current_user
         ) do
      {:ok, _content} ->
        {:noreply, socket}

      {:error, error} ->
        Logger.error("Error marking content not watched #{inspect(error)}")
        {:noreply, socket |> put_flash(:error, "Something wrong happened")}
    end
  end
end
