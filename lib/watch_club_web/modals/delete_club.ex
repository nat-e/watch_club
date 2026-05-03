defmodule WatchClubWeb.Modals.DeleteClub do
  require Logger
  use WatchClubWeb, :live_component

  @modal_name "delete_club"
  def modal_name, do: @modal_name

  @impl true
  def render(%{current_user: %User{}, club: %Club{}} = assigns) do
    ~H"""
    <div>
      <.dialog>
        <:title>Delete club</:title>
        <.separator class="my-2" />
        <p>
          Are you sure you want to delete <span class="font-bold">{@club.name}</span> ?
        </p>
        <p>All the members will be removed and the data will be deleted permanently.</p>
        <div class="flex justify-end gap-2">
          <.button
            type="button"
            class="w-fit self-end"
            variant="outline"
            phx-click="cancel"
            phx-target={@myself}
          >
            Cancel
          </.button>

          <.button
            class="w-fit self-end"
            variant="destructive"
            phx-click="submit"
            phx-target={@myself}
          >
            Delete
          </.button>
        </div>
      </.dialog>
    </div>
    """
  end

  @impl true
  def handle_event("submit", _params, socket) do
    %{club: %Club{} = club, current_user: %User{} = user} = socket.assigns

    case Clubs.destroy_club(club, actor: user) do
      :ok ->
        send(self(), {:close_modal, @modal_name, []})
        send(self(), {:put_flash, :success, "Club #{club.name} deleted"})
        {:noreply, socket}

      {:error, error} ->
        send(self(), {:close_modal, @modal_name, []})
        send(self(), {:put_flash, :error, "Error deleting club, try again later"})
        Logger.error("Error deleting club", error)
        {:noreply, socket}
    end
  end

  def handle_event("cancel", _params, socket) do
    send(self(), {:close_modal, @modal_name, []})
    {:noreply, socket}
  end
end
