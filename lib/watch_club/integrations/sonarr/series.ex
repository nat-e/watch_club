defmodule WatchClub.Integrations.Sonarr.Series do
  @moduledoc false

  @type t :: %__MODULE__{
          id: integer() | nil,
          tvdb_id: integer() | nil,
          imdb_id: String.t() | nil,
          tmdb_id: integer() | nil,
          title: String.t() | nil,
          quality_profile_id: integer() | nil,
          root_folder_path: String.t() | nil,
          status: String.t() | nil,
          episode_count: non_neg_integer(),
          episode_file_count: non_neg_integer()
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
    episode_count: 0,
    episode_file_count: 0
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
      status: data["status"],
      episode_count: get_in(data, ["statistics", "episodeCount"]) || 0,
      episode_file_count: get_in(data, ["statistics", "episodeFileCount"]) || 0
    }
  end

  defp value_or_nil(""), do: nil
  defp value_or_nil(value), do: value
end
