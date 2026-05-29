defmodule WatchClub.Integrations.Servarr.Webhook.MediaFile do
  @moduledoc """
  Shared shape of Radarr's `movieFile` / Sonarr's `episodeFile`.

  `relative_path` is relative to the content folder; join them for the
  library path. `path` (server-absolute) is not trusted for the library
  location — at import time it can be the download-client path.
  """

  @type t :: %__MODULE__{
          relative_path: String.t() | nil,
          path: String.t() | nil
        }

  defstruct [:relative_path, :path]

  @spec from_api(map() | nil) :: t() | nil
  def from_api(nil), do: nil

  def from_api(data) when is_map(data) do
    %__MODULE__{
      relative_path: data["relativePath"],
      path: data["path"]
    }
  end
end
