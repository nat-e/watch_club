defmodule WatchClub.Media.MediaImport.OrphansCleanup do
  @moduledoc """
  Cancels any `MediaImport` left in `:processing` by a previous BEAM that died
  without finishing its work (SIGKILL, OOM, host crash, graceful shutdown that
  outran its grace period).

  Runs synchronously in `init/1` and returns `:ignore` so the GenServer exits
  cleanly. Placed after `Oban` and `Phoenix.PubSub` and before `Endpoint` in
  the supervision tree, which gives three guarantees:

    * Oban is started, so the bulk update's `Changes.CancelObanJobs` hook can
      cancel the underlying Oban jobs.
    * `Phoenix.PubSub` is started, so the `:cancel` action's PubSub notifier
      can broadcast.
    * The web endpoint hasn't started yet, so no fresh `MediaImport` can be
      created before cleanup completes.
  """

  use GenServer

  require Ash.Query
  require Logger

  alias WatchClub.Media
  alias WatchClub.Media.MediaImport
  alias WatchClub.SystemActor

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [])

  @impl true
  def init(_) do
    run()
    :ignore
  end

  defp run do
    MediaImport
    |> Ash.Query.filter(status == :processing)
    |> Media.cancel_media_import(
      actor: SystemActor.actor(),
      bulk_options: [return_records?: true]
    )
    |> log_result()
  catch
    kind, reason ->
      Logger.error(
        "MediaImport orphans cleanup failed: #{inspect(kind)} #{inspect(reason)}\n" <>
          Exception.format_stacktrace(__STACKTRACE__)
      )

      :ok
  end

  defp log_result(%Ash.BulkResult{status: :success, records: []}), do: :ok

  defp log_result(%Ash.BulkResult{status: :success, records: records}) do
    Logger.info("Cancelled #{length(records)} orphaned MediaImport(s) from previous run")
  end

  defp log_result(%Ash.BulkResult{status: status, errors: errors}) do
    Logger.error("Orphan MediaImport cleanup finished with status #{status}: #{inspect(errors)}")
  end
end
