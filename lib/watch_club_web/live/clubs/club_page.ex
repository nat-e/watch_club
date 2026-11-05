defmodule WatchClubWeb.Clubs.ClubPage do
  use WatchClubWeb, :live_view

  on_mount {WatchClubWeb.Hooks.LoadClub, false}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      title={@club.name}
    >
    </Layouts.app>
    """
  end

  # The club was renamed: the bar shows its name
  @impl true
  def handle_info(
        %Notification{data: %Club{id: club_id} = club, action: %{type: :update}},
        socket
      )
      when club_id == socket.assigns.club.id do
    {:noreply, assign(socket, :club, club)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}
end
