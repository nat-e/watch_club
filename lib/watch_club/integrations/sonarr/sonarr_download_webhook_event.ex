defmodule WatchClub.Integrations.Sonarr.SonarrDownloadWebhookEvent do
  @moduledoc """
  Parsed Sonarr `Download` webhook payload — an episode file imported into
  the library. One `episodeFile` can cover several `episodes`. Owns Sonarr's
  JSON field names; mapping onto `Media` candidates is the caller's job.
  """

  alias WatchClub.Integrations.Servarr.Webhook.MediaFile

  defmodule Episode do
    @moduledoc "An episode of the downloaded file, with its numbers, title, air date and TVDB id."

    @type t :: %__MODULE__{
            season_number: integer() | nil,
            episode_number: integer() | nil,
            title: String.t() | nil,
            air_date: Date.t() | nil,
            tvdb_id: integer() | nil
          }

    defstruct [:season_number, :episode_number, :title, :air_date, :tvdb_id]

    @spec from_api(map()) :: t()
    def from_api(data) when is_map(data) do
      %__MODULE__{
        season_number: data["seasonNumber"],
        episode_number: data["episodeNumber"],
        title: data["title"],
        air_date: WatchClub.Helpers.maybe_date!(data["airDate"]),
        tvdb_id: data["tvdbId"]
      }
    end
  end

  @type t :: %__MODULE__{
          tvdb_id: integer() | nil,
          tmdb_id: integer() | nil,
          imdb_id: String.t() | nil,
          title: String.t() | nil,
          series_path: String.t() | nil,
          episodes: [Episode.t()],
          file: MediaFile.t() | nil,
          upgrade?: boolean()
        }

  defstruct [
    :tvdb_id,
    :tmdb_id,
    :imdb_id,
    :title,
    :series_path,
    :file,
    episodes: [],
    upgrade?: false
  ]

  @spec from_api(map()) :: t()
  def from_api(params) when is_map(params) do
    series = params["series"] || %{}

    %__MODULE__{
      tvdb_id: series["tvdbId"],
      tmdb_id: series["tmdbId"],
      imdb_id: value_or_nil(series["imdbId"]),
      title: series["title"],
      series_path: series["path"],
      episodes: Enum.map(params["episodes"] || [], &Episode.from_api/1),
      file: MediaFile.from_api(params["episodeFile"]),
      upgrade?: params["isUpgrade"] == true
    }
  end

  defp value_or_nil(""), do: nil
  defp value_or_nil(value), do: value
end
