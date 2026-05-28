defmodule WatchClub.Media.RadarrMediaSource.Workers.DeleteRadarrWebhook do
  @moduledoc """
  Best-effort cleanup of a Radarr notification after its
  `RadarrMediaSource` was destroyed. Scheduled by an
  `after_transaction` hook on the destroy action; the row is already
  gone by the time the job runs, so every value the call needs is
  carried in the job args.

  The args contract lives here — callers go through `new_job/1` rather
  than building the args map themselves.
  """
  use Oban.Worker, queue: :media_source_webhooks, max_attempts: 5

  alias WatchClub.Integrations.Radarr
  alias WatchClub.Media.RadarrMediaSource

  @doc """
  Builds an `Oban.Job` from a `RadarrMediaSource` record (typically a
  freshly destroyed one). Insert with `Oban.insert/1` or `insert!/1`.
  """
  def new_job(%RadarrMediaSource{} = record) do
    new(%{
      "base_url" => record.base_url,
      "api_key" => record.api_key,
      "notification_id" => record.radarr_notification_id
    })
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "base_url" => base_url,
          "api_key" => api_key,
          "notification_id" => notification_id
        }
      }) do
    case Radarr.delete_webhook(base_url, api_key, notification_id) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
