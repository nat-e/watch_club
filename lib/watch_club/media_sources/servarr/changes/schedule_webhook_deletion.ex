defmodule WatchClub.MediaSources.Servarr.Changes.ScheduleWebhookDeletion do
  @moduledoc """
  After the destroy transaction commits, enqueue an Oban job that asks the
  server to delete the registered Webhook notification. Args carry
  everything the worker needs because the row is gone by the time it runs.
  """
  use Ash.Resource.Change

  alias WatchClub.MediaSources.Servarr.Workers.DeleteWebhook

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, record} <- result do
        record |> DeleteWebhook.new_job() |> Oban.insert!()
        {:ok, record}
      end
    end)
  end
end
