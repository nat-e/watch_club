defmodule WatchClubWeb.Admin.InstanceSettingsPage do
  @moduledoc """
  Instance-administrator settings page. Currently a stub: the destination
  exists so the sidebar Admin entry has somewhere to navigate, but the
  configurable settings themselves land in a follow-up.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Settings.SettingsHeader

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="section"
      class="max-w-panel"
    >
      <.settings_header
        title={dgettext("admin_instance_settings", "Instance settings")}
        description={
          dgettext(
            "admin_instance_settings",
            "Configure the Watch Club instance itself. More options coming soon."
          )
        }
      />

      <.empty>
        <:icon><Lucideicons.settings_2 /></:icon>
        <:title>{dgettext("admin_instance_settings", "Nothing here yet")}</:title>
        <:description>
          {dgettext(
            "admin_instance_settings",
            "Instance settings will appear here in a future release."
          )}
        </:description>
      </.empty>
    </Layouts.app>
    """
  end
end
