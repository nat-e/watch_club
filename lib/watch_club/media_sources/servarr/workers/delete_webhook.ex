defmodule WatchClub.MediaSources.Servarr.Workers.DeleteWebhook do
  @moduledoc """
  Best-effort cleanup of a notification after its `Servarr` was
  destroyed. Scheduled by an `after_transaction` hook on the destroy
  action; the row is already gone by the time the job runs, so every value
  the call needs is carried in the job args.

  Deletion is flavor-agnostic (id-only, no body), so the job carries no
  flavor. The args contract lives here — callers go through `new_job/1`
  rather than building the args map themselves.
  """
  use Oban.Worker, queue: :media_source_webhooks, max_attempts: 5

  alias WatchClub.Integrations.Servarr.Client
  alias WatchClub.MediaSources.Servarr

  @doc """
  Builds an `Oban.Job` from a `Servarr` record (typically a
  freshly destroyed one). Insert with `OpentelemetryOban.insert!/1`.
  """
  def new_job(%Servarr{} = record) do
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
    {:ok, :deleted} = Client.delete_notification(base_url, api_key, notification_id)
    :ok
  end
end
