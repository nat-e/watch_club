defmodule WatchClub.Contents.Preparations.FilterByTitle do
  @moduledoc """
  Keeps the Content whose original title or one of its localized titles contains the `query`
  argument, ignoring case and accents. Keeps every Content when `query` is nil.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    case Ash.Query.get_argument(query, :query) do
      nil ->
        query

      text ->
        Ash.Query.filter(
          query,
          fragment("strpos(unaccent(lower(?)), unaccent(lower(?))) > 0", original_title, ^text) or
            exists(
              movie.localizations,
              fragment("strpos(unaccent(lower(?)), unaccent(lower(?))) > 0", title, ^text)
            ) or
            exists(
              tv_show.localizations,
              fragment("strpos(unaccent(lower(?)), unaccent(lower(?))) > 0", title, ^text)
            )
        )
    end
  end
end
