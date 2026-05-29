defmodule WatchClub.Media.MediaImport.Changes.CancelObanJobs do
  @moduledoc """
  After the cancel transition commits, cancel every Oban job that was
  carrying work for this Media Import — the `ScanMediaSource`, any pending
  or executing `ImportMediaFile` candidates, and the `MonitorMediaImport`
  monitor. All Media Import jobs are tagged `media_import:<uuid>`, so a
  single `Oban.cancel_all_jobs/1` sweeps them all and pkills the in-flight
  ones across the cluster.

  Stale Media Imports whose jobs are already gone (terminal states) are a
  no-op.
  """

  use Ash.Resource.Change

  import Ecto.Query

  alias WatchClub.Media.MediaImport

  require Logger

  @cancellable_states ~w(available scheduled executing retryable)

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, %MediaImport{id: media_import_id} = media_import} <- result do
        tag = "media_import:#{media_import_id}"

        query =
          from(j in Oban.Job,
            where: fragment("? @> ?", j.tags, ^[tag]),
            where: j.state in ^@cancellable_states
          )

        case Oban.cancel_all_jobs(query) do
          {:ok, 0} ->
            :ok

          {:ok, count} ->
            Logger.info("Cancelled #{count} Oban job(s) for MediaImport #{media_import_id}")
        end

        {:ok, media_import}
      end
    end)
  end
end
