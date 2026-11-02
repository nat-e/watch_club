defmodule WatchClubWeb.Components.Medias.UnmatchedContentSection do
  @moduledoc """
  Placeholder block for a media whose file has no matched piece of content.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.UI.Layout
  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Admin.MediaBrowserPage.Filename

  attr :file_name, :string, required: true

  def unmatched_content_section(assigns) do
    ~H"""
    <div class="flex items-start gap-cluster">
      <.tmdb_poster
        size="w185"
        alt={@file_name}
        class="w-24 shrink-0 border border-border-subtle"
      />

      <.stack space="related" class="min-w-0 flex-1 self-center">
        <h2 class="text-xl font-heading font-semibold leading-tight tracking-tight text-text">
          {dgettext("admin_media", "Unmatched")}
        </h2>
        <.file_name file_name={@file_name} class="text-sm text-text-muted" wrap />
      </.stack>
    </div>
    """
  end
end
