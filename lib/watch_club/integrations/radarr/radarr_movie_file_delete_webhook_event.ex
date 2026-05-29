defmodule WatchClub.Integrations.Radarr.RadarrMovieFileDeleteWebhookEvent do
  @moduledoc """
  Parsed Radarr `MovieFileDelete` webhook payload — a movie file was removed.
  Carries only what locating the affected `Media` needs (the file's folder +
  relative path); the disk, not `deleteReason`, decides whether to remove it.
  """

  alias WatchClub.Integrations.Servarr.Webhook.MediaFile

  @type t :: %__MODULE__{folder_path: String.t() | nil, file: MediaFile.t() | nil}

  defstruct [:folder_path, :file]

  @spec from_api(map()) :: t()
  def from_api(params) when is_map(params) do
    movie = params["movie"] || %{}

    %__MODULE__{
      folder_path: movie["folderPath"],
      file: MediaFile.from_api(params["movieFile"])
    }
  end
end
