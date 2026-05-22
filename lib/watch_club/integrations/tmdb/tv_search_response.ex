defmodule WatchClub.Integrations.Tmdb.TvSearchResponse do
  @moduledoc false

  alias WatchClub.Integrations.Tmdb.TvSearchResult

  @type t :: %__MODULE__{
          page: pos_integer(),
          results: [TvSearchResult.t()],
          total_pages: non_neg_integer(),
          total_results: non_neg_integer()
        }

  defstruct [:page, :results, :total_pages, :total_results]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      page: data["page"],
      results: Enum.map(data["results"] || [], &TvSearchResult.from_api/1),
      total_pages: data["total_pages"],
      total_results: data["total_results"]
    }
  end
end
