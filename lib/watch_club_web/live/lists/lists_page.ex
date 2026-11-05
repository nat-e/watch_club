defmodule WatchClubWeb.Lists.ListsPage do
  @moduledoc """
  The Playlists tab's page, empty.
  """
  use WatchClubWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      title={dgettext("nav", "Playlists")}
    >
    </Layouts.app>
    """
  end
end
