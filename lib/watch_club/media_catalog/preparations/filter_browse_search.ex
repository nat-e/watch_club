defmodule WatchClub.MediaCatalog.Preparations.FilterBrowseSearch do
  @moduledoc """
  Filters Media by a free-text term across the media path and the titles
  of any attached content (movie, TV show, ebook, audiobook).
  """
  use Ash.Resource.Preparation

  import Ash.Expr
  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    case Ash.Query.get_argument(query, :search) do
      term when is_binary(term) and term != "" ->
        pattern = "%" <> term <> "%"

        Ash.Query.filter(
          query,
          expr(
            fragment("? ILIKE ?", path, ^pattern) or
              fragment("? ILIKE ?", video.movie.content.original_title, ^pattern) or
              fragment(
                "? ILIKE ?",
                video.tv_show_episode.tv_show.content.original_title,
                ^pattern
              ) or
              fragment("? ILIKE ?", ebook.book.title, ^pattern) or
              fragment("? ILIKE ?", audiobook.book.title, ^pattern)
          )
        )

      _ ->
        query
    end
  end
end
