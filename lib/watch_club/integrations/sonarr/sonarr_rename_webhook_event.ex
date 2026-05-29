defmodule WatchClub.Integrations.Sonarr.SonarrRenameWebhookEvent do
  @moduledoc """
  Parsed Sonarr `Rename` webhook payload — one or more episode files were
  renamed/moved within the library. Carries the series folder and each
  file's previous + new location; mapping onto `Media` is the caller's job.
  """

  alias WatchClub.Integrations.Servarr.Webhook.RenamedFile

  @type t :: %__MODULE__{series_path: String.t() | nil, renamed_files: [RenamedFile.t()]}

  defstruct [:series_path, renamed_files: []]

  @spec from_api(map()) :: t()
  def from_api(params) when is_map(params) do
    series = params["series"] || %{}

    %__MODULE__{
      series_path: series["path"],
      renamed_files: Enum.map(params["renamedEpisodeFiles"] || [], &RenamedFile.from_api/1)
    }
  end
end
