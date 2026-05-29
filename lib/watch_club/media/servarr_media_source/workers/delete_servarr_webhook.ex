defmodule WatchClub.Media.ServarrMediaSource.Workers.DeleteServarrWebhook do
  @moduledoc """
  Best-effort cleanup of a notification after its `ServarrMediaSource` was
  destroyed. Scheduled by an `after_transaction` hook on the destroy
  action; the row is already gone by the time the job runs, so every value
  the call needs is carried in the job args.

  Deletion is flavor-agnostic (id-only, no body), so the job carries no
  flavor. The args contract lives here — callers go through `new_job/1`
  rather than building the args map themselves.
  """
  use Oban.Worker, queue: :media_source_webhooks, max_attempts: 5

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.Media.ServarrMediaSource

  @doc """
  Builds an `Oban.Job` from a `ServarrMediaSource` record (typically a
  freshly destroyed one). Insert with `Oban.insert/1` or `insert!/1`.
  """
  def new_job(%ServarrMediaSource{} = record) do
    new(%{
      "base_url" => record.base_url,
      "api_key" => record.api_key,
      "notification_id" => record.notification_id
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
    case Client.delete_notification(base_url, api_key, notification_id) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
