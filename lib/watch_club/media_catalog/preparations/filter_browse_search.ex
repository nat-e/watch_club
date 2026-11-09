defmodule WatchClub.MediaCatalog.Preparations.FilterBrowseSearch do
  @moduledoc """
  Keeps the Media whose path, or title as the actor sees it, contains the `search` argument,
  ignoring case and accents.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    text = Ash.Query.get_argument(query, :search)

    Ash.Query.filter(
      query,
      fragment("strpos(unaccent(lower(?)), unaccent(lower(?))) > 0", path, ^text) or
        fragment("strpos(?, unaccent(lower(?))) > 0", content.localized_title_key, ^text)
    )
  end
end
