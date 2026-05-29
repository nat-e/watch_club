defmodule WatchClub.Integrations.Sonarr.Series do
  @moduledoc false

  @type t :: %__MODULE__{
          id: integer() | nil,
          tvdb_id: integer() | nil,
          imdb_id: String.t() | nil,
          tmdb_id: integer() | nil,
          title: String.t() | nil,
          quality_profile_id: integer() | nil,
          root_folder_path: String.t() | nil
        }

  defstruct [
    :id,
    :tvdb_id,
    :imdb_id,
    :tmdb_id,
    :title,
    :quality_profile_id,
    :root_folder_path
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
      root_folder_path: data["rootFolderPath"]
    }
  end

  defp value_or_nil(""), do: nil
  defp value_or_nil(value), do: value
end
