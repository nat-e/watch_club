defmodule WatchClubWeb.Components.Contents.SeasonWatchProgressBadge do
  @moduledoc """
  Badge representing the watch progress status of the current user for a season of a TvShow
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
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:status, season_status(assigns.content, assigns.season_number))}
  end

  @impl true
  def handle_event("mark_watched", _params, socket) do
    user = socket.assigns.current_user

    with {:ok, content} <- ContentView.ensure_content_exists(socket.assigns.content, user),
         {:ok, _} <-
           Contents.mark_show_season_watched(
             content.content.tv_show,
             %{season_number: socket.assigns.season_number},
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
           Contents.mark_show_season_not_watched(
             content.content.tv_show,
             %{season_number: socket.assigns.season_number},
             actor: user
           ) do
      {:noreply, socket}
    else
      {:error, error} ->
        Logger.error("Error marking content not watched #{inspect(error)}")
        {:noreply, socket |> put_flash(:error, "Something wrong happened")}
    end
  end

  defp season_status(%ContentView{content: nil}, _season), do: :not_started

  defp season_status(%ContentView{content: content}, season_number) do
    episodes = content.tv_show.episodes |> Enum.filter(&(&1.season_number == season_number))

    cond do
      Enum.all?(episodes, &(&1.viewer_progress_status == :not_started)) -> :not_started
      Enum.all?(episodes, &(&1.viewer_progress_status == :completed)) -> :completed
      true -> :in_progress
    end
  end
end
