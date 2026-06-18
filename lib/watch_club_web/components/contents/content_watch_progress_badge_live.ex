defmodule WatchClubWeb.Components.Contents.ContentWatchProgressBadge do
  @moduledoc """
  Badge representing the watch progress status of the current user for a given Content.
  """
  use WatchClubWeb, :live_component

  alias WatchClub.Contents.ContentIdentity

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
  def update_many(assigns_sockets) do
    identities = Enum.map(assigns_sockets, fn {assigns, _socket} -> assigns.content_identity end)

    actor = assigns_sockets |> List.first() |> Kernel.elem(0) |> Map.fetch!(:current_user)

    contents_by_identity =
      Contents.get_contents_by_identities!(identities,
        load: [:actor_progress_status],
        actor: actor
      )
      |> Map.new(&{ContentIdentity.from_content(&1), &1})

    assigns_sockets
    |> Enum.map(fn {assigns, socket} ->
      content = Map.get(contents_by_identity, assigns.content_identity)

      socket
      |> assign(assigns)
      |> assign(status: (content && content.actor_progress_status) || :not_started)
    end)
  end

  @impl true
  def handle_event("mark_watched", _params, socket) do
    case History.mark_content_watched(socket.assigns.content_identity,
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
    case History.mark_content_not_watched(socket.assigns.content_identity,
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
