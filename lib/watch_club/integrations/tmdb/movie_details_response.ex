defmodule WatchClub.Integrations.Tmdb.MovieDetailsResponse do
  @moduledoc false

  defmodule Collection do
    @moduledoc false
    @type t :: %__MODULE__{
            id: integer(),
            name: String.t(),
            poster_path: String.t() | nil,
            backdrop_path: String.t() | nil
          }

    defstruct [:id, :name, :poster_path, :backdrop_path]

    @spec from_api(map() | nil) :: t() | nil
    def from_api(nil), do: nil

    def from_api(data) do
      %__MODULE__{
        id: data["id"],
        name: data["name"],
        poster_path: data["poster_path"],
        backdrop_path: data["backdrop_path"]
      }
    end
  end

  defmodule Genre do
    @moduledoc false
    @type t :: %__MODULE__{id: integer(), name: String.t()}

    defstruct [:id, :name]

    @spec from_api(map()) :: t()
    def from_api(data), do: %__MODULE__{id: data["id"], name: data["name"]}
  end

  defmodule ProductionCompany do
    @moduledoc false
    @type t :: %__MODULE__{
            id: integer(),
            name: String.t(),
            logo_path: String.t() | nil,
            origin_country: String.t()
          }

    defstruct [:id, :name, :logo_path, :origin_country]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{
        id: data["id"],
        name: data["name"],
        logo_path: data["logo_path"],
        origin_country: data["origin_country"]
      }
    end
  end

  defmodule ProductionCountry do
    @moduledoc false
    @type t :: %__MODULE__{iso_3166_1: String.t(), name: String.t()}

    defstruct [:iso_3166_1, :name]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{iso_3166_1: data["iso_3166_1"], name: data["name"]}
    end
  end

  defmodule Translation do
    @moduledoc false

    defmodule Data do
      @moduledoc false
      @type t :: %__MODULE__{
              homepage: String.t() | nil,
              overview: String.t() | nil,
              runtime: integer() | nil,
              tagline: String.t() | nil,
              title: String.t() | nil
            }

      defstruct [:homepage, :overview, :runtime, :tagline, :title]

      @spec from_api(map()) :: t()
      def from_api(data) do
        %__MODULE__{
          homepage: data["homepage"],
          overview: data["overview"],
          runtime: data["runtime"],
          tagline: data["tagline"],
          title: data["title"]
        }
      end
    end

    @type t :: %__MODULE__{
            iso_3166_1: String.t(),
            iso_639_1: String.t(),
            name: String.t(),
            english_name: String.t(),
            data: Data.t()
          }

    defstruct [:iso_3166_1, :iso_639_1, :name, :english_name, :data]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{
        iso_3166_1: data["iso_3166_1"],
        iso_639_1: data["iso_639_1"],
        name: data["name"],
        english_name: data["english_name"],
        data: Data.from_api(data["data"] || %{})
      }
    end
  end

  defmodule Image do
    @moduledoc false
    @type t :: %__MODULE__{
            aspect_ratio: float(),
            height: integer(),
            iso_639_1: String.t() | nil,
            file_path: String.t(),
            vote_average: float(),
            vote_count: integer(),
            width: integer()
          }

    defstruct [
      :aspect_ratio,
      :height,
      :iso_639_1,
      :file_path,
      :vote_average,
      :vote_count,
      :width
    ]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{
        aspect_ratio: data["aspect_ratio"],
        height: data["height"],
        iso_639_1: data["iso_639_1"],
        file_path: data["file_path"],
        vote_average: data["vote_average"],
        vote_count: data["vote_count"],
        width: data["width"]
      }
    end
  end

  defmodule Images do
    @moduledoc false
    @type t :: %__MODULE__{
            backdrops: [Image.t()],
            logos: [Image.t()],
            posters: [Image.t()]
          }

    defstruct backdrops: [], logos: [], posters: []

    @spec from_api(map() | nil) :: t() | nil
    def from_api(nil), do: nil

    def from_api(data) do
      %__MODULE__{
        backdrops: Enum.map(data["backdrops"] || [], &Image.from_api/1),
        logos: Enum.map(data["logos"] || [], &Image.from_api/1),
        posters: Enum.map(data["posters"] || [], &Image.from_api/1)
      }
    end
  end

  defmodule SpokenLanguage do
    @moduledoc false
    @type t :: %__MODULE__{
            iso_639_1: String.t(),
            name: String.t(),
            english_name: String.t()
          }

    defstruct [:iso_639_1, :name, :english_name]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{
        iso_639_1: data["iso_639_1"],
        name: data["name"],
        english_name: data["english_name"]
      }
    end
  end

  @type t :: %__MODULE__{
          adult: boolean(),
          backdrop_path: String.t() | nil,
          belongs_to_collection: Collection.t() | nil,
          budget: integer(),
          genres: [Genre.t()],
          homepage: String.t() | nil,
          id: integer(),
          images: Images.t() | nil,
          imdb_id: String.t() | nil,
          origin_country: [String.t()],
          original_language: String.t(),
          original_title: String.t(),
          overview: String.t() | nil,
          popularity: float(),
          poster_path: String.t() | nil,
          production_companies: [ProductionCompany.t()],
          production_countries: [ProductionCountry.t()],
          release_date: Date.t() | nil,
          revenue: integer(),
          runtime: integer() | nil,
          spoken_languages: [SpokenLanguage.t()],
          status: String.t(),
          tagline: String.t() | nil,
          title: String.t(),
          translations: [Translation.t()],
          video: boolean(),
          vote_average: float(),
          vote_count: integer()
        }

  defstruct [
    :adult,
    :backdrop_path,
    :belongs_to_collection,
    :budget,
    :genres,
    :homepage,
    :id,
    :images,
    :imdb_id,
    :origin_country,
    :original_language,
    :original_title,
    :overview,
    :popularity,
    :poster_path,
    :production_companies,
    :production_countries,
    :release_date,
    :revenue,
    :runtime,
    :spoken_languages,
    :status,
    :tagline,
    :title,
    :translations,
    :video,
    :vote_average,
    :vote_count
  ]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      adult: data["adult"],
      backdrop_path: data["backdrop_path"],
      belongs_to_collection: Collection.from_api(data["belongs_to_collection"]),
      budget: data["budget"],
      genres: Enum.map(data["genres"] || [], &Genre.from_api/1),
      homepage: data["homepage"],
      id: data["id"],
      images: Images.from_api(data["images"]),
      imdb_id: data["imdb_id"],
      origin_country: data["origin_country"] || [],
      original_language: data["original_language"],
      original_title: data["original_title"],
      overview: data["overview"],
      popularity: data["popularity"],
      poster_path: data["poster_path"],
      production_companies:
        Enum.map(data["production_companies"] || [], &ProductionCompany.from_api/1),
      production_countries:
        Enum.map(data["production_countries"] || [], &ProductionCountry.from_api/1),
      release_date: WatchClub.Helpers.maybe_date!(data["release_date"]),
      revenue: data["revenue"],
      runtime: data["runtime"],
      spoken_languages: Enum.map(data["spoken_languages"] || [], &SpokenLanguage.from_api/1),
      status: data["status"],
      tagline: data["tagline"],
      title: data["title"],
      translations:
        Enum.map(
          get_in(data, ["translations", "translations"]) || [],
          &Translation.from_api/1
        ),
      video: data["video"],
      vote_average: data["vote_average"],
      vote_count: data["vote_count"]
    }
  end
end
