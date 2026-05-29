defmodule WatchClubWeb.Components.Media.SourceIdentifier do
  @moduledoc """
  Compact monospace chip that identifies a Media Source.

  Filesystem sources show the filesystem path; Radarr / Sonarr sources show
  `host · root_folder_path`.
  """
  use WatchClubWeb, :component

  alias WatchClub.Media.MediaSource

  attr :media_source, MediaSource, required: true

  def source_identifier(%{media_source: %MediaSource{source_type: :filesystem}} = assigns) do
    ~H"""
    <.badge variant="muted" class="rounded-sm">
      <:icon><.lucide_icon name="folder" /></:icon>
      <span class="truncate">{@media_source.implementation.filesystem_path}</span>
    </.badge>
    """
  end

  def source_identifier(%{media_source: %MediaSource{source_type: type}} = assigns)
      when type in [:radarr, :sonarr] do
    ~H"""
    <.badge variant="muted" class="rounded-sm">
      <:icon><.lucide_icon name="link" /></:icon>
      <span class="truncate">
        {WatchClubWeb.Helpers.Url.strip_scheme(@media_source.implementation.base_url)}
      </span>
    </.badge>
    <.badge variant="muted" class="rounded-sm">
      <:icon><.lucide_icon name="sparkles" /></:icon>
      <span class="truncate">
        {@media_source.implementation.quality_profile_name}
      </span>
    </.badge>
    <.badge variant="muted" class="rounded-sm">
      <:icon><.lucide_icon name="folder" /></:icon>
      <span class="truncate">{@media_source.implementation.root_folder_path}</span>
    </.badge>
    """
  end
end
