defmodule WatchClub.Integrations.Sonarr.Series do
  @moduledoc false

  @type status :: :continuing | :ended | :upcoming | :deleted

  @statuses %{
    "continuing" => :continuing,
    "ended" => :ended,
    "upcoming" => :upcoming,
    "deleted" => :deleted
  }

  defmodule Statistics do
    @type t :: %__MODULE__{
            episode_count: non_neg_integer(),
            episode_file_count: non_neg_integer()
          }
    defstruct [:episode_count, :episode_file_count]
  end

  @type t :: %__MODULE__{
          id: integer(),
          tvdb_id: integer(),
          imdb_id: String.t() | nil,
          tmdb_id: integer(),
          title: String.t() | nil,
          quality_profile_id: integer(),
          root_folder_path: String.t() | nil,
          status: status(),
          statistics: Statistics.t()
        }

  defstruct [
    :id,
    :tvdb_id,
    :imdb_id,
    :tmdb_id,
    :title,
    :quality_profile_id,
    :root_folder_path,
    :status,
    :statistics
  ]

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      tvdb_id: data["tvdbId"],
      imdb_id: value_or_nil(data["imdbId"]),
      tmdb_id: data["tmdbId"],
      title: data["title"],
      quality_profile_id: data["qualityProfileId"],
      root_folder_path: data["rootFolderPath"],
      status: Map.fetch!(@statuses, data["status"]),
      statistics: %Statistics{
        episode_count: get_in(data, ["statistics", "episodeCount"]),
        episode_file_count: get_in(data, ["statistics", "episodeFileCount"])
      }
    }
  end

  defp value_or_nil(""), do: nil
  defp value_or_nil(value), do: value
end
