defmodule WatchClub.Contents.SearchResultsPage do
  @moduledoc """
  A single page of content search results, carrying the external provider's
  pagination metadata so callers can request the following pages.
  """
  alias WatchClub.Integrations.Tmdb.{MovieSearchResult, TvSearchResult}

  @type result :: MovieSearchResult.t() | TvSearchResult.t()

  @type t :: %__MODULE__{
          results: [result()],
          page: pos_integer(),
          total_pages: non_neg_integer()
        }

  defstruct results: [], page: 1, total_pages: 0
end
