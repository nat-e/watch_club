defmodule WatchClub.Integrations.Radarr.RadarrDownloadWebhookEvent do
  @moduledoc """
  Parsed Radarr `Download` webhook payload — a movie file imported into the
  library. Owns Radarr's JSON field names; mapping onto a `Media` candidate
  is the caller's job.
  """

  alias WatchClub.Integrations.Servarr.Webhook.MediaFile

  @type t :: %__MODULE__{
          tmdb_id: integer() | nil,
          imdb_id: String.t() | nil,
          title: String.t() | nil,
          year: integer() | nil,
          folder_path: String.t() | nil,
          file: MediaFile.t() | nil,
          upgrade?: boolean()
        }

  defstruct [:tmdb_id, :imdb_id, :title, :year, :folder_path, :file, upgrade?: false]

  @spec from_api(map()) :: t()
  def from_api(params) when is_map(params) do
    movie = params["movie"] || %{}

    %__MODULE__{
      tmdb_id: movie["tmdbId"],
      imdb_id: value_or_nil(movie["imdbId"]),
      title: movie["title"],
      year: movie["year"],
      folder_path: movie["folderPath"],
      file: MediaFile.from_api(params["movieFile"]),
      upgrade?: params["isUpgrade"] == true
    }
  end

  defp value_or_nil(""), do: nil
  defp value_or_nil(value), do: value
end
