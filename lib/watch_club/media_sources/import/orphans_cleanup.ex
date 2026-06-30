defmodule WatchClub.MediaSources.Import.OrphansCleanup do
  @moduledoc """
  Cancels any `Import` left in `:processing` by a previous BEAM that died
  without finishing its work (SIGKILL, OOM, host crash, graceful shutdown that
  outran its grace period).

  Runs synchronously in `init/1` and returns `:ignore` so the GenServer exits
  cleanly. Placed after `Oban` and `Phoenix.PubSub` and before `Endpoint` in
  the supervision tree, which gives three guarantees:

    * Oban is started, so the bulk update's `Changes.CancelObanJobs` hook can
      cancel the underlying Oban jobs.
    * `Phoenix.PubSub` is started, so the `:cancel` action's PubSub notifier
      can broadcast.
    * The web endpoint hasn't started yet, so no fresh `Import` can be
      created before cleanup completes.
  """

  use GenServer

  require Ash.Query
  require Logger

  alias WatchClub.MediaSources
  alias WatchClub.MediaSources.Import
  alias WatchClub.SystemActor

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [])

  @impl true
  def init(_) do
    run()
    :ignore
  end

  defp run do
    Import
    |> Ash.Query.filter(status == :processing)
    |> MediaSources.cancel_media_import(
      actor: SystemActor.actor(),
      bulk_options: [return_records?: true]
    )
  catch
    kind, reason ->
      Logger.error(
        "Import orphans cleanup failed",
        event: :orphans_cleanup_failed,
        error: Exception.format(kind, reason, __STACKTRACE__)
      )

      :ok
  end
end
