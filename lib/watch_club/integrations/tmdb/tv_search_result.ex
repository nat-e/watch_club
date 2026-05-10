defmodule WatchClub.Integrations.Tmdb.TvSearchResult do
  @moduledoc false
  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          original_name: String.t(),
          original_language: String.t(),
          overview: String.t(),
          poster_path: String.t() | nil,
          backdrop_path: String.t() | nil,
          genre_ids: [integer()],
          popularity: float(),
          first_air_date: Date.t() | nil,
          origin_country: [String.t()],
          vote_average: float(),
          vote_count: integer(),
          adult: boolean()
        }

  defstruct [
    :id,
    :name,
    :original_name,
    :original_language,
    :overview,
    :poster_path,
    :backdrop_path,
    :genre_ids,
    :popularity,
    :first_air_date,
    :origin_country,
    :vote_average,
    :vote_count,
    :adult
  ]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      original_name: data["original_name"],
      original_language: data["original_language"],
      overview: data["overview"],
      poster_path: data["poster_path"],
      backdrop_path: data["backdrop_path"],
      genre_ids: data["genre_ids"] || [],
      popularity: data["popularity"],
      first_air_date: WatchClub.Helpers.maybe_date!(data["first_air_date"]),
      origin_country: data["origin_country"] || [],
      vote_average: data["vote_average"],
      vote_count: data["vote_count"],
      adult: data["adult"]
    }
  end
end
