defmodule WatchClub.Integrations.Tmdb.MovieSearchResult do
  @moduledoc false
  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          original_title: String.t(),
          original_language: String.t(),
          overview: String.t(),
          poster_path: String.t() | nil,
          backdrop_path: String.t() | nil,
          genre_ids: [integer()],
          popularity: float(),
          release_date: Date.t() | nil,
          video: boolean(),
          vote_average: float(),
          vote_count: integer(),
          adult: boolean()
        }

  defstruct [
    :id,
    :title,
    :original_title,
    :original_language,
    :overview,
    :poster_path,
    :backdrop_path,
    :genre_ids,
    :popularity,
    :release_date,
    :video,
    :vote_average,
    :vote_count,
    :adult
  ]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      id: data["id"],
      title: data["title"],
      original_title: data["original_title"],
      original_language: data["original_language"],
      overview: data["overview"],
      poster_path: data["poster_path"],
      backdrop_path: data["backdrop_path"],
      genre_ids: data["genre_ids"] || [],
      popularity: data["popularity"],
      release_date: WatchClub.Helpers.maybe_date!(data["release_date"]),
      video: data["video"],
      vote_average: data["vote_average"],
      vote_count: data["vote_count"],
      adult: data["adult"]
    }
  end
end
