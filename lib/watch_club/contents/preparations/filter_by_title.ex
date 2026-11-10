defmodule WatchClub.Contents.Preparations.FilterByTitle do
  @moduledoc """
  Keeps the Content whose original title or one of its localized titles contains each word of
  the `query` argument, in any order, ignoring case and accents.
  """
  use Ash.Resource.Preparation

  import Ash.Expr

  require Ash.Query

  alias WatchClub.Shared.WordSearch

  @impl true
  def prepare(query, _opts, _context) do
    words = query |> Ash.Query.get_argument(:query) |> WordSearch.words()

    Ash.Query.filter(
      query,
      ^WordSearch.contains_every_word(ref(:original_title), words) or
        exists(movie.localizations, ^WordSearch.contains_every_word(ref(:title), words)) or
        exists(tv_show.localizations, ^WordSearch.contains_every_word(ref(:title), words))
    )
  end
end
