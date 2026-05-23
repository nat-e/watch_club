defmodule WatchClubWeb.Admin.MediaImportsPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Settings.SettingsHeader

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="section"
    >
      <.settings_header
        title="Media Imports"
        description="Configure how media is imported into this instance."
      />
    </Layouts.app>
    """
  end
end
