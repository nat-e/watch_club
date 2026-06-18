defmodule WatchClub.Contents.Preparations.LoadContentForView do
  @moduledoc """
  Loads all the field of a Content necessary to build a ContentView for the current user.
  """
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, _context) do
    Ash.Query.load(query, [
      :viewer_progress_status,
      library_items: [:library, :added_by],
      viewer_request: [:status, :status_group, :progress],
      book: [:audiobooks, :ebooks, :playable?],
      movie: [:videos, :playable?],
      tv_show: [
        viewer_next_episode: [:videos, :playable?, :viewer_progress_status],
        episodes: [:videos, :playable?, :viewer_progress_status]
      ]
    ])
  end
end
