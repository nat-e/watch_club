defmodule WatchClub.Integrations.Servarr.QueueItem do
  @moduledoc """
  One record from a Radarr/Sonarr download queue (`/api/v3/queue/details`).
  Identical shape across products; only the fields the reconciler needs are
  parsed.
  """

  @type t :: %__MODULE__{
          status: String.t() | nil,
          tracked_download_status: String.t() | nil,
          tracked_download_state: String.t() | nil
        }

  defstruct [:status, :tracked_download_status, :tracked_download_state]

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      status: data["status"],
      tracked_download_status: data["trackedDownloadStatus"],
      tracked_download_state: data["trackedDownloadState"]
    }
  end

  @doc "True when the item needs manual intervention on the *arr side."
  @spec blocked?(t()) :: boolean()
  def blocked?(%__MODULE__{tracked_download_status: status}), do: status in ["warning", "error"]
end
