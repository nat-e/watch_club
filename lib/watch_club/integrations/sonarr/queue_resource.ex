defmodule WatchClub.Integrations.Sonarr.QueueResource do
  @moduledoc """
  https://sonarr.tv/docs/api/#v3/models/QueueResource

  One record from a Radarr/Sonarr download queue (`/api/v3/queue/details`).
  Identical shape across products; only the fields we use are parsed.

  The `status` enums are translated to atoms at the boundary.
  An unrecognized value (e.g. one a newer *arr release adds) is mapped as :unknown
  """

  @type status ::
          :unknown
          | :queued
          | :paused
          | :downloading
          | :completed
          | :failed
          | :warning
          | :delay
          | :download_client_unavailable
          | :fallback

  @type t :: %__MODULE__{
          episode_id: number(),
          status: status(),
          size: number(),
          size_left: number()
        }

  defstruct [
    :episode_id,
    :status,
    :size,
    :size_left
  ]

  @statuses %{
    "unknown" => :unknown,
    "queued" => :queued,
    "paused" => :paused,
    "downloading" => :downloading,
    "completed" => :completed,
    "failed" => :failed,
    "warning" => :warning,
    "delay" => :delay,
    "downloadClientUnavailable" => :download_client_unavailable,
    "fallback" => :fallback
  }

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      episode_id: Map.fetch!(data, "episodeId"),
      status: Map.get(@statuses, data["status"], :unknown),
      size: Map.fetch!(data, "size"),
      # Radarr/Sonarr are migrating this key from `sizeleft` to `sizeLeft`; accept either.
      size_left: Map.get(data, "sizeleft") || Map.fetch!(data, "sizeLeft")
    }
  end

  @doc "True when the item needs manual intervention on the *arr side."
  @spec blocked?(t()) :: boolean()
  def blocked?(%__MODULE__{status: status}),
    do: status in [:warning, :failed, :download_client_unavailable]

  @doc """
  The percentage of progress of the download
  """
  @spec download_progress(t()) :: float()
  def download_progress(%__MODULE__{size: 0}), do: 0

  def download_progress(%__MODULE__{size: size, size_left: left}),
    do: (size - left) / size * 100.0
end
