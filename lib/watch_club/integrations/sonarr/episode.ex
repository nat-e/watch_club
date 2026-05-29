defmodule WatchClub.Integrations.Sonarr.Episode do
  @moduledoc """
  One Sonarr episode, parsed from `GET /api/v3/episode?seriesId=…&
  includeEpisodeFile=true`. The embedded `episodeFile` (when present)
  carries the on-disk path; season/episode numbers come from the episode
  itself.
  """

  @type t :: %__MODULE__{
          series_id: integer() | nil,
          season_number: integer() | nil,
          episode_number: integer() | nil,
          has_file?: boolean(),
          file_path: String.t() | nil
        }

  defstruct [
    :series_id,
    :season_number,
    :episode_number,
    :file_path,
    has_file?: false
  ]

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      series_id: data["seriesId"],
      season_number: data["seasonNumber"],
      episode_number: data["episodeNumber"],
      has_file?: Map.get(data, "hasFile", false) == true,
      file_path: get_in(data, ["episodeFile", "path"])
    }
  end
end
