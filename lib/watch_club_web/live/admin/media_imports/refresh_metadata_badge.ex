defmodule WatchClubWeb.Admin.MediaImports.RefreshMetadataBadge do
  @moduledoc """
  Refresh-metadata badge for a `Media Import` row.
  """
  use WatchClubWeb, :component

  attr :value, :boolean, required: true

  def refresh_metadata_badge(%{value: true} = assigns) do
    ~H"""
    <.badge variant="secondary" size="sm">
      <:icon><Lucideicons.refresh_cw /></:icon>
      {dgettext("admin_media_imports", "On")}
    </.badge>
    """
  end

  def refresh_metadata_badge(%{value: false} = assigns) do
    ~H"""
    <.badge variant="secondary" size="sm">
      {dgettext("admin_media_imports", "Off")}
    </.badge>
    """
  end
end
