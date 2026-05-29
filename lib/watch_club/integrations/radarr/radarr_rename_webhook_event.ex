defmodule WatchClub.Integrations.Radarr.RadarrRenameWebhookEvent do
  @moduledoc """
  Parsed Radarr `Rename` webhook payload — one or more movie files were
  renamed/moved within the library. Carries the content folder and each
  file's previous + new location; mapping onto `Media` is the caller's job.
  """

  alias WatchClub.Integrations.Servarr.Webhook.RenamedFile

  @type t :: %__MODULE__{folder_path: String.t() | nil, renamed_files: [RenamedFile.t()]}

  defstruct [:folder_path, renamed_files: []]

  @spec from_api(map()) :: t()
  def from_api(params) when is_map(params) do
    movie = params["movie"] || %{}

    %__MODULE__{
      folder_path: movie["folderPath"],
      renamed_files: Enum.map(params["renamedMovieFiles"] || [], &RenamedFile.from_api/1)
    }
  end
end
