defmodule WatchClub.Integrations.Tmdb.TvDetailsResponse do
  @moduledoc false

  defmodule ExternalIds do
    @moduledoc false
    @type t :: %__MODULE__{tvdb_id: integer() | nil}

    defstruct [:tvdb_id]

    @spec from_api(map() | nil) :: t()
    def from_api(data) do
      %__MODULE__{tvdb_id: data && data["tvdb_id"]}
    end
  end

  defmodule Image do
    @moduledoc false
    @type t :: %__MODULE__{iso_639_1: String.t() | nil, file_path: String.t()}

    defstruct [:iso_639_1, :file_path]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{iso_639_1: data["iso_639_1"], file_path: data["file_path"]}
    end
  end

  defmodule Images do
    @moduledoc false
    @type t :: %__MODULE__{posters: [Image.t()]}

    defstruct posters: []

    @spec from_api(map() | nil) :: t() | nil
    def from_api(nil), do: nil

    def from_api(data) do
      %__MODULE__{posters: Enum.map(data["posters"] || [], &Image.from_api/1)}
    end
  end

  defmodule Season do
    @moduledoc false
    @type t :: %__MODULE__{season_number: integer(), episode_count: non_neg_integer()}

    defstruct [:season_number, :episode_count]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{
        season_number: data["season_number"],
        episode_count: data["episode_count"] || 0
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
          external_ids: ExternalIds.t(),
          first_air_date: Date.t() | nil,
          id: integer(),
          images: Images.t() | nil,
          name: String.t(),
          origin_country: [String.t()],
          original_language: String.t(),
          original_name: String.t(),
          overview: String.t() | nil,
          poster_path: String.t() | nil,
          seasons: [Season.t()],
          translations: [Translation.t()]
        }

  defstruct [
    :external_ids,
    :first_air_date,
    :id,
    :images,
    :name,
    :origin_country,
    :original_language,
    :original_name,
    :overview,
    :poster_path,
    :seasons,
    :translations
  ]

  @spec from_api(map()) :: t()
  def from_api(data) do
    %__MODULE__{
      external_ids: ExternalIds.from_api(data["external_ids"]),
      first_air_date: WatchClub.Helpers.maybe_date!(data["first_air_date"]),
      id: data["id"],
      images: Images.from_api(data["images"]),
      name: data["name"],
      origin_country: data["origin_country"] || [],
      original_language: data["original_language"],
      original_name: data["original_name"],
      overview: data["overview"],
      poster_path: data["poster_path"],
      seasons: Enum.map(data["seasons"] || [], &Season.from_api/1),
      translations:
        Enum.map(
          get_in(data, ["translations", "translations"]) || [],
          &Translation.from_api/1
        )
    }
  end
end
