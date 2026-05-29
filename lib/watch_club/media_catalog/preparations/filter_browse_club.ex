defmodule WatchClub.MediaCatalog.Preparations.FilterBrowseClub do
  @moduledoc """
  Filters Media to those whose attached content is in a library belonging
  to the given club, across all media kinds (movie, TV show, ebook,
  audiobook).
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    case Ash.Query.get_argument(query, :club_id) do
      nil ->
        query

      club_id ->
        Ash.Query.filter(
          query,
          exists(video.movie.content.library_items.library, club_id == ^club_id) or
            exists(
              video.tv_show_episode.tv_show.content.library_items.library,
              club_id == ^club_id
            ) or
            exists(ebook.book.content.library_items.library, club_id == ^club_id) or
            exists(audiobook.book.content.library_items.library, club_id == ^club_id)
        )
    end
  end
end
