defmodule WatchClub.Media.ImportRun.Changes.CancelObanJob do
  @moduledoc """
  After the cancel transition commits, find the run's Oban job and tell
  Oban to cancel it. Oban marks the row `cancelled` and broadcasts a
  `pkill` signal that terminates the executor process on whichever node
  is running it (see `Oban.queue/producer.ex:pkill/3`).

  Stale runs whose Oban job is already gone are a no-op.
  """

  use Ash.Resource.Change

  import Ecto.Query

  alias WatchClub.Media.ImportRun
  alias WatchClub.Repo

  require Logger

  @cancellable_states ~w(available scheduled executing retryable)

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, %ImportRun{id: run_id} = run} <- result do
        case find_job_id(run_id) do
          nil ->
            :ok

          job_id ->
            :ok = Oban.cancel_job(job_id)
            Logger.info("Cancelled Oban job #{job_id} for ImportRun #{run_id}")
        end

        {:ok, run}
      end
    end)
  end

  defp find_job_id(run_id) do
    trigger = AshOban.Info.oban_trigger(ImportRun, :run)
    worker_name = inspect(trigger.worker)

    from(job in Oban.Job,
      where: job.worker == ^worker_name,
      where: fragment("?->'primary_key'->>'id' = ?", job.args, ^run_id),
      where: job.state in ^@cancellable_states,
      select: job.id,
      limit: 1
    )
    |> Repo.one()
  end
end
