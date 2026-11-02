defmodule WatchClubWeb.Components.Contents.EpisodeWatchProgressBadge do
  @moduledoc """
  Badge representing the watch progress status of the current user for a given TvShowEpisode
  """
  use WatchClubWeb, :live_component

  alias WatchClub.Contents.ContentIdentity

  attr :content_identity, ContentIdentity, required: true
  attr :season_number, :integer, required: true
  attr :episode_number, :integer, required: true
  attr :status, :atom, required: true

  @impl true
  def render(%{status: :completed} = assigns) do
    ~H"""
    <button class="w-fit" phx-target={@myself} phx-click="mark_not_watched">
      <.badge variant="success">
        <:icon><Lucideicons.check_circle_2 /></:icon>
        {dgettext("contents", "Watched")}
      </.badge>
    </button>
    """
  end

  def render(assigns) do
    ~H"""
    <button class="w-fit" phx-target={@myself} phx-click="mark_watched">
      <.badge variant="muted">
        <:icon><Lucideicons.check_circle_2 /></:icon>
        {dgettext("contents", "Mark as watched")}
      </.badge>
    </button>
    """
  end

  @impl true
  def handle_event("mark_watched", _params, socket) do
    History.mark_content_watched!(
      socket.assigns.content_identity,
      %{
        season_number: socket.assigns.season_number,
        episode_number: socket.assigns.episode_number
      },
      actor: socket.assigns.current_user
    )

    {:noreply, socket}
  end

  def handle_event("mark_not_watched", _params, socket) do
    History.mark_content_not_watched!(
      socket.assigns.content_identity,
      %{
        season_number: socket.assigns.season_number,
        episode_number: socket.assigns.episode_number
      },
      actor: socket.assigns.current_user
    )

    {:noreply, socket}
  end
end
