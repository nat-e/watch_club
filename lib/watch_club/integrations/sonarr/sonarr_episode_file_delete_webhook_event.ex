defmodule WatchClub.Integrations.Sonarr.SonarrEpisodeFileDeleteWebhookEvent do
  @moduledoc """
  Parsed Sonarr `EpisodeFileDelete` webhook payload — an episode file was
  removed. Carries only what locating the affected `Media` needs (the file's
  series folder + relative path); the disk, not `deleteReason`, decides
  whether to remove it.
  """

  alias WatchClub.Integrations.Servarr.Webhook.MediaFile

  @type t :: %__MODULE__{series_path: String.t() | nil, file: MediaFile.t() | nil}

  defstruct [:series_path, :file]

  @spec from_api(map()) :: t()
  def from_api(params) when is_map(params) do
    series = params["series"] || %{}

    %__MODULE__{
      series_path: series["path"],
      file: MediaFile.from_api(params["episodeFile"])
    }
  end
end
