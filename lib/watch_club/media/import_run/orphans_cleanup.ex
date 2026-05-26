defmodule WatchClub.Media.ImportRun.OrphansCleanup do
  @moduledoc """
  Cancels any `ImportRun` left in `:processing` by a previous BEAM that died
  without finishing its work (SIGKILL, OOM, host crash, graceful shutdown that
  outran its grace period).

  Runs synchronously in `init/1` and returns `:ignore` so the GenServer exits
  cleanly. Sits between the `Oban` and `Endpoint` children in the supervision
  tree, which gives two guarantees:

    * Oban is started, so the bulk update's `Changes.CancelObanJob` hook can
      cancel the underlying Oban jobs.
    * The web endpoint hasn't started yet, so no fresh `ImportRun` can be
      created before cleanup completes.
  """

  use GenServer

  require Ash.Query
  require Logger

  alias WatchClub.Media
  alias WatchClub.Media.ImportRun
  alias WatchClub.SystemActor

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [])

  @impl true
  def init(_) do
    run()
    :ignore
  end

  defp run do
    ImportRun
    |> Ash.Query.filter(status == :processing)
    |> Media.cancel_import_run(actor: SystemActor.actor())
    |> log_result()
  catch
    kind, reason ->
      Logger.error("ImportRun orphans cleanup failed: #{inspect(kind)} #{inspect(reason)}")

      :ok
  end

  defp log_result(%Ash.BulkResult{status: :success, records: []}), do: :ok

  defp log_result(%Ash.BulkResult{status: :success, records: records}) do
    Logger.info("Cancelled #{length(records)} orphaned ImportRun(s) from previous run")
  end

  defp log_result(%Ash.BulkResult{status: status, errors: errors}) do
    Logger.error("Orphan ImportRun cleanup finished with status #{status}: #{inspect(errors)}")
  end
end
