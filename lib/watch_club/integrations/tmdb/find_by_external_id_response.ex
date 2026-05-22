defmodule WatchClub.Integrations.Tmdb.FindByExternalIdResponse do
  @moduledoc false

  alias WatchClub.Integrations.Tmdb.{MovieSearchResult, TvSearchResult}

  @type t :: %__MODULE__{
          movie_results: [MovieSearchResult.t()],
          tv_results: [TvSearchResult.t()]
        }

  defstruct movie_results: [], tv_results: []

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      movie_results: Enum.map(data["movie_results"] || [], &MovieSearchResult.from_api/1),
      tv_results: Enum.map(data["tv_results"] || [], &TvSearchResult.from_api/1)
    }
  end
end
