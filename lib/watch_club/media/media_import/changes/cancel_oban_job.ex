defmodule WatchClub.Media.MediaImport.Changes.CancelObanJob do
  @moduledoc """
  After the cancel transition commits, find the Media Import's Oban job and
  tell Oban to cancel it. Oban marks the row `cancelled` and broadcasts a
  `pkill` signal that terminates the executor process on whichever node is
  running it (see `Oban.queue/producer.ex:pkill/3`).

  Stale Media Imports whose Oban job is already gone are a no-op.
  """

  use Ash.Resource.Change

  import Ecto.Query

  alias WatchClub.Media.MediaImport
  alias WatchClub.Repo

  require Logger

  @cancellable_states ~w(available scheduled executing retryable)

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, %MediaImport{id: media_import_id} = media_import} <- result do
        case find_job_id(media_import_id) do
          nil ->
            :ok

          job_id ->
            :ok = Oban.cancel_job(job_id)
            Logger.info("Cancelled Oban job #{job_id} for MediaImport #{media_import_id}")
        end

        {:ok, media_import}
      end
    end)
  end

  defp find_job_id(media_import_id) do
    trigger = AshOban.Info.oban_trigger(MediaImport, :run)
    worker_name = inspect(trigger.worker)

    from(job in Oban.Job,
      where: job.worker == ^worker_name,
      where: fragment("?->'primary_key'->>'id' = ?", job.args, ^media_import_id),
      where: job.state in ^@cancellable_states,
      select: job.id,
      limit: 1
    )
    |> Repo.one()
  end
end
