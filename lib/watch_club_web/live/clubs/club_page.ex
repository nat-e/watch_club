defmodule WatchClubWeb.Clubs.ClubPage do
  use WatchClubWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
    >
    </Layouts.app>
    """
  end
end
