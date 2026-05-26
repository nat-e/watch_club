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
    <div class="grid grid-cols-[6rem_minmax(0,1fr)] items-start gap-cluster">
      <.tmdb_poster
        size="w185"
        alt={@file_name}
        class="rounded-control border border-border-subtle"
      />

      <.stack space="related" class="min-w-0 self-center">
        <h2 class="text-xl font-heading font-semibold leading-tight tracking-tight text-text">
          Unmatched
        </h2>
        <.file_name file_name={@file_name} class="text-sm text-text-muted" wrap />
      </.stack>
    </div>
    """
  end
end
