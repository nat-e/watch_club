defmodule WatchClub.Integrations.Tmdb.Types do
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

    @doc """
    The path of the backdrop to show: one without text first, then a 16:9 one. Nil when there's
    none.
    """
    @spec best_backdrop_path(t() | nil) :: String.t() | nil
    def best_backdrop_path(%__MODULE__{backdrops: [_ | _] = backdrops}) do
      backdrops
      |> Enum.min_by(fn backdrop ->
        # Language-neutral first: nil → false. Then 16:9, which TMDB rounds up to 1.778.
        {not is_nil(backdrop.iso_639_1), backdrop.aspect_ratio != 1.778}
      end)
      |> Map.fetch!(:file_path)
    end

    def best_backdrop_path(_images), do: nil
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

  defmodule Credit do
    @moduledoc false
    @type t :: %__MODULE__{
            id: integer(),
            name: String.t(),
            character: String.t() | nil,
            job: String.t() | nil,
            profile_path: String.t() | nil,
            order: integer() | nil
          }

    defstruct [:id, :name, :character, :job, :profile_path, :order]

    @spec from_cast_api(map()) :: t()
    def from_cast_api(data) do
      %__MODULE__{
        id: data["id"],
        name: data["name"],
        character: data["character"],
        profile_path: data["profile_path"],
        order: data["order"]
      }
    end

    @spec from_crew_api(map()) :: t()
    def from_crew_api(data) do
      %__MODULE__{
        id: data["id"],
        name: data["name"],
        job: data["job"],
        profile_path: data["profile_path"]
      }
    end
  end

  defmodule Credits do
    @moduledoc false
    @type t :: %__MODULE__{cast: [Credit.t()], crew: [Credit.t()]}

    defstruct cast: [], crew: []

    @spec from_api(map() | nil) :: t() | nil
    def from_api(nil), do: nil

    def from_api(data) do
      %__MODULE__{
        cast: Enum.map(data["cast"] || [], &Credit.from_cast_api/1),
        crew: Enum.map(data["crew"] || [], &Credit.from_crew_api/1)
      }
    end
  end

  defmodule Video do
    @moduledoc false
    @type t :: %__MODULE__{
            id: String.t(),
            key: String.t(),
            name: String.t(),
            official: boolean(),
            site: String.t(),
            type: String.t()
          }

    defstruct [:id, :key, :name, :official, :site, :type]

    @spec from_api(map()) :: t()
    def from_api(data) do
      %__MODULE__{
        id: data["id"],
        key: data["key"],
        name: data["name"],
        official: data["official"],
        site: data["site"],
        type: data["type"]
      }
    end
  end

  defmodule Videos do
    @moduledoc false
    @type t :: %__MODULE__{results: [Video.t()]}

    defstruct results: []

    @spec from_api(map() | nil) :: t() | nil
    def from_api(nil), do: nil

    def from_api(data) do
      %__MODULE__{results: Enum.map(data["results"] || [], &Video.from_api/1)}
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

  defmodule Genre do
    @moduledoc false
    @type t :: %__MODULE__{id: integer(), name: String.t()}

    defstruct [:id, :name]

    @spec from_api(map()) :: t()
    def from_api(data), do: %__MODULE__{id: data["id"], name: data["name"]}
  end
end
