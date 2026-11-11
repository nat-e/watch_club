defmodule WatchClub.Integrations.Tmdb.FindByExternalIdResponse do
  @moduledoc false

  alias WatchClub.Integrations.Tmdb.{MovieSearchResult, TvSearchResult}

  defmodule TvEpisodeResult do
    @moduledoc "A TV episode found by another catalog's id, such as a TVDB episode id."

    @type t :: %__MODULE__{
            show_id: integer(),
            season_number: integer(),
            episode_number: integer()
          }

    defstruct [:show_id, :season_number, :episode_number]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{
        show_id: data["show_id"],
        season_number: data["season_number"],
        episode_number: data["episode_number"]
      }
    end
  end

  @type t :: %__MODULE__{
          movie_results: [MovieSearchResult.t()],
          tv_results: [TvSearchResult.t()],
          tv_episode_results: [TvEpisodeResult.t()]
        }

  defstruct movie_results: [], tv_results: [], tv_episode_results: []

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      movie_results: Enum.map(data["movie_results"] || [], &MovieSearchResult.from_api/1),
      tv_results: Enum.map(data["tv_results"] || [], &TvSearchResult.from_api/1),
      tv_episode_results: Enum.map(data["tv_episode_results"] || [], &TvEpisodeResult.from_api/1)
    }
  end
end
