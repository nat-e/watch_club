defmodule WatchClub.Integrations.Sonarr.Episode do
  @moduledoc """
  https://sonarr.tv/docs/api/#v3/models/EpisodeResource
  """

  @type t :: %__MODULE__{
          id: integer(),
          series_id: integer(),
          season_number: integer(),
          episode_number: integer(),
          has_file?: boolean(),
          file_path: String.t() | nil,
          air_date_utc: DateTime.t() | nil
        }

  defstruct [
    :id,
    :series_id,
    :season_number,
    :episode_number,
    :file_path,
    :has_file?,
    :air_date_utc
  ]

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.fetch!(data, "id"),
      series_id: Map.fetch!(data, "seriesId"),
      season_number: Map.fetch!(data, "seasonNumber"),
      episode_number: Map.fetch!(data, "episodeNumber"),
      has_file?: Map.get(data, "hasFile", false) == true,
      file_path: get_in(data, ["episodeFile", "path"]),
      air_date_utc: WatchClub.Helpers.maybe_datetime!(data["airDateUtc"])
    }
  end
end
