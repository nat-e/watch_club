defmodule WatchClub.Media.RadarrMediaSource.Changes.ScheduleWebhookDeletion do
  @moduledoc """
  After the destroy transaction commits, enqueue an Oban job that asks
  Radarr to delete the registered Webhook notification. Args carry
  everything the worker needs because the row is gone by the time it
  runs.
  """
  use Ash.Resource.Change

  alias WatchClub.Media.RadarrMediaSource.Workers.DeleteRadarrWebhook

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, record} <- result do
        record |> DeleteRadarrWebhook.new_job() |> Oban.insert!()
        {:ok, record}
      end
    end)
  end
end
