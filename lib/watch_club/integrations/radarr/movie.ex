defmodule WatchClub.Integrations.Radarr.Movie do
  @moduledoc false

  @type t :: %__MODULE__{
          id: integer() | nil,
          tmdb_id: integer() | nil,
          imdb_id: String.t() | nil,
          title: String.t() | nil,
          year: integer() | nil,
          has_file?: boolean(),
          available?: boolean(),
          quality_profile_id: integer() | nil,
          root_folder_path: String.t() | nil,
          file_path: String.t() | nil
        }

  defstruct [
    :id,
    :tmdb_id,
    :imdb_id,
    :title,
    :year,
    :quality_profile_id,
    :root_folder_path,
    :file_path,
    has_file?: false,
    available?: true
  ]

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      id: data["id"],
      tmdb_id: data["tmdbId"],
      imdb_id: value_or_nil(data["imdbId"]),
      title: data["title"],
      year: data["year"],
      has_file?: Map.get(data, "hasFile", false) == true,
      available?: Map.get(data, "isAvailable", true) == true,
      quality_profile_id: data["qualityProfileId"],
      root_folder_path: data["rootFolderPath"],
      file_path: get_in(data, ["movieFile", "path"])
    }
  end

  defp value_or_nil(""), do: nil
  defp value_or_nil(value), do: value
end
