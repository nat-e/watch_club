defmodule WatchClub.Integrations.Tmdb.TvDetailsResponse do
  @moduledoc false

  alias WatchClub.Integrations.Tmdb.Types.{
    Credit,
    Credits,
    Genre,
    Images,
    ProductionCountry,
    SpokenLanguage,
    Videos
  }

  defmodule ExternalIds do
    @moduledoc false
    @type t :: %__MODULE__{imdb_id: String.t() | nil, tvdb_id: integer() | nil}

    defstruct [:imdb_id, :tvdb_id]

    @spec from_api(map() | nil) :: t()
    def from_api(data) do
      %__MODULE__{imdb_id: data && data["imdb_id"], tvdb_id: data && data["tvdb_id"]}
    end
  end

  defmodule Season do
    @moduledoc false
    @type t :: %__MODULE__{
            air_date: Date.t() | nil,
            episode_count: non_neg_integer(),
            id: integer() | nil,
            name: String.t() | nil,
            overview: String.t() | nil,
            poster_path: String.t() | nil,
            season_number: integer(),
            vote_average: number() | nil
          }

    defstruct [
      :air_date,
      :episode_count,
      :id,
      :name,
      :overview,
      :poster_path,
      :season_number,
      :vote_average
    ]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{
        air_date: WatchClub.Helpers.maybe_date!(data["air_date"]),
        episode_count: data["episode_count"] || 0,
        id: data["id"],
        name: data["name"],
        overview: data["overview"],
        poster_path: data["poster_path"],
        season_number: data["season_number"],
        vote_average: data["vote_average"]
      }
    end
  end

  defmodule SeasonDetails do
    @moduledoc false

    defmodule Episode do
      @moduledoc false
      @type t :: %__MODULE__{
              air_date: Date.t() | nil,
              crew: [Credit.t()],
              episode_number: integer(),
              episode_type: String.t() | nil,
              guest_stars: [Credit.t()],
              id: integer(),
              name: String.t(),
              overview: String.t() | nil,
              production_code: String.t() | nil,
              runtime: integer() | nil,
              season_number: integer(),
              show_id: integer() | nil,
              still_path: String.t() | nil,
              vote_average: number() | nil,
              vote_count: integer() | nil
            }

      defstruct [
        :air_date,
        :episode_number,
        :episode_type,
        :id,
        :name,
        :overview,
        :production_code,
        :runtime,
        :season_number,
        :show_id,
        :still_path,
        :vote_average,
        :vote_count,
        crew: [],
        guest_stars: []
      ]

      @spec from_api(map()) :: t()
      def from_api(data) do
        %__MODULE__{
          air_date: WatchClub.Helpers.maybe_date!(data["air_date"]),
          crew: Enum.map(data["crew"] || [], &Credit.from_crew_api/1),
          episode_number: data["episode_number"],
          episode_type: data["episode_type"],
          guest_stars: Enum.map(data["guest_stars"] || [], &Credit.from_cast_api/1),
          id: data["id"],
          name: data["name"],
          overview: data["overview"],
          production_code: data["production_code"],
          runtime: data["runtime"],
          season_number: data["season_number"],
          show_id: data["show_id"],
          still_path: data["still_path"],
          vote_average: data["vote_average"],
          vote_count: data["vote_count"]
        }
      end
    end

    @type t :: %__MODULE__{
            air_date: Date.t() | nil,
            episodes: [Episode.t()],
            id: integer() | nil,
            name: String.t() | nil,
            overview: String.t() | nil,
            poster_path: String.t() | nil,
            season_number: integer(),
            vote_average: number() | nil
          }

    defstruct [
      :air_date,
      :id,
      :name,
      :overview,
      :poster_path,
      :season_number,
      :vote_average,
      episodes: []
    ]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{
        air_date: WatchClub.Helpers.maybe_date!(data["air_date"]),
        episodes: Enum.map(data["episodes"] || [], &Episode.from_api/1),
        id: data["id"],
        name: data["name"],
        overview: data["overview"],
        poster_path: data["poster_path"],
        season_number: data["season_number"],
        vote_average: data["vote_average"]
      }
    end
  end

  defmodule Translation do
    @moduledoc false

    defmodule Data do
      @moduledoc false
      @type t :: %__MODULE__{name: String.t() | nil, overview: String.t() | nil}

      defstruct [:name, :overview]

      @spec from_api(map()) :: t()
      def from_api(data) do
        %__MODULE__{name: data["name"], overview: data["overview"]}
      end
    end

    @type t :: %__MODULE__{
            iso_3166_1: String.t(),
            iso_639_1: String.t(),
            data: Data.t()
          }

    defstruct [:iso_3166_1, :iso_639_1, :data]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{
        iso_3166_1: data["iso_3166_1"],
        iso_639_1: data["iso_639_1"],
        data: Data.from_api(data["data"] || %{})
      }
    end
  end

  @type t :: %__MODULE__{
          adult: boolean() | nil,
          backdrop_path: String.t() | nil,
          credits: Credits.t() | nil,
          episode_run_time: [integer()],
          external_ids: ExternalIds.t(),
          first_air_date: Date.t() | nil,
          genres: [Genre.t()],
          homepage: String.t() | nil,
          id: integer(),
          images: Images.t() | nil,
          in_production: boolean() | nil,
          languages: [String.t()],
          last_air_date: Date.t() | nil,
          name: String.t(),
          number_of_episodes: integer() | nil,
          number_of_seasons: integer() | nil,
          origin_country: [String.t()],
          original_language: String.t(),
          original_name: String.t(),
          overview: String.t() | nil,
          poster_path: String.t() | nil,
          production_countries: [ProductionCountry.t()],
          season_details: [SeasonDetails.t()],
          seasons: [Season.t()],
          spoken_languages: [SpokenLanguage.t()],
          status: String.t() | nil,
          tagline: String.t() | nil,
          translations: [Translation.t()],
          videos: Videos.t() | nil,
          vote_average: number() | nil,
          vote_count: integer() | nil
        }

  defstruct [
    :adult,
    :backdrop_path,
    :credits,
    :external_ids,
    :first_air_date,
    :homepage,
    :id,
    :images,
    :in_production,
    :last_air_date,
    :name,
    :number_of_episodes,
    :number_of_seasons,
    :original_language,
    :original_name,
    :overview,
    :poster_path,
    :status,
    :tagline,
    :videos,
    :vote_average,
    :vote_count,
    episode_run_time: [],
    genres: [],
    languages: [],
    origin_country: [],
    production_countries: [],
    season_details: [],
    seasons: [],
    spoken_languages: [],
    translations: []
  ]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      adult: data["adult"],
      backdrop_path: data["backdrop_path"],
      credits: Credits.from_api(data["credits"]),
      episode_run_time: data["episode_run_time"] || [],
      external_ids: ExternalIds.from_api(data["external_ids"]),
      first_air_date: WatchClub.Helpers.maybe_date!(data["first_air_date"]),
      genres: Enum.map(data["genres"] || [], &Genre.from_api/1),
      homepage: data["homepage"],
      id: data["id"],
      images: Images.from_api(data["images"]),
      in_production: data["in_production"],
      languages: data["languages"] || [],
      last_air_date: WatchClub.Helpers.maybe_date!(data["last_air_date"]),
      name: data["name"],
      number_of_episodes: data["number_of_episodes"],
      number_of_seasons: data["number_of_seasons"],
      origin_country: data["origin_country"] || [],
      original_language: data["original_language"],
      original_name: data["original_name"],
      overview: data["overview"],
      poster_path: data["poster_path"],
      production_countries:
        Enum.map(data["production_countries"] || [], &ProductionCountry.from_api/1),
      seasons: Enum.map(data["seasons"] || [], &Season.from_api/1),
      spoken_languages: Enum.map(data["spoken_languages"] || [], &SpokenLanguage.from_api/1),
      status: data["status"],
      tagline: data["tagline"],
      translations:
        Enum.map(
          get_in(data, ["translations", "translations"]) || [],
          &Translation.from_api/1
        ),
      videos: Videos.from_api(data["videos"]),
      vote_average: data["vote_average"],
      vote_count: data["vote_count"]
    }
  end
end
