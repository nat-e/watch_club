defmodule WatchClub.Integrations.Tmdb.PersonSearchResult do
  @moduledoc false
  alias WatchClub.Integrations.Tmdb.{MovieSearchResult, TvSearchResult}

  @type known_for :: MovieSearchResult.t() | TvSearchResult.t()

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          original_name: String.t(),
          gender: integer() | nil,
          known_for_department: String.t() | nil,
          profile_path: String.t() | nil,
          popularity: float(),
          known_for: [known_for()],
          adult: boolean()
        }

  defstruct [
    :id,
    :name,
    :original_name,
    :gender,
    :known_for_department,
    :profile_path,
    :popularity,
    :known_for,
    :adult
  ]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      original_name: data["original_name"],
      gender: data["gender"],
      known_for_department: data["known_for_department"],
      profile_path: data["profile_path"],
      popularity: data["popularity"],
      known_for: parse_known_for(data["known_for"] || []),
      adult: data["adult"]
    }
  end

  defp parse_known_for(items) do
    Enum.flat_map(items, fn
      %{"media_type" => "movie"} = item -> [MovieSearchResult.from_api(item)]
      %{"media_type" => "tv"} = item -> [TvSearchResult.from_api(item)]
      _ -> []
    end)
  end
end
