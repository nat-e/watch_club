defmodule WatchClub.Shared.ObanLogger do
  @moduledoc """
  Logs Oban job `:stop`/`:exception` telemetry as structured Logger metadata
  so `WatchClub.Shared.LogFormatter` can render concise lines.

  Oban's own `attach_default_logger/1` logs a report into the message body
  with only `domain: [:oban]` as metadata, so a metadata-based formatter can
  never reach the fields. Attaching this handler instead puts them where the
  formatter expects them.
  """

  require Logger

  @job_events [
    [:oban, :job, :start],
    [:oban, :job, :stop],
    [:oban, :job, :exception]
  ]

  # Ignore start/stop for some very verbose jobs, and for those that log their own outcome. Oban
  # stores `worker` as a string, so match against the inspected module names.
  @ignored_workers [
    "WatchClub.MediaSources.Import.Workers.CandidateIngestor",
    "WatchClub.MediaSources.Import.Workers.ImportMonitor",
    "WatchClub.Playbacks.Workers.EndAbandonedSessions",
    "WatchClub.Requests.Workers.RefreshMediaSourceRequest"
  ]

  @doc "Attaches the handler. Call once on application start."
  def attach do
    :telemetry.attach_many("watch-club-oban-logger", @job_events, &__MODULE__.handle_event/4, nil)
  end

  # Every job's logs get its metadata, including the ignored workers' own logs
  def handle_event([:oban, :job, :start], _measure, meta, _config) do
    Logger.metadata(metadata(meta))

    if meta.worker not in @ignored_workers do
      Logger.log(:info, "#{meta.worker} job started", args: meta.args)
    end
  end

  def handle_event([:oban, :job, :stop], measure, meta, _config)
      when meta.worker not in @ignored_workers do
    Logger.log(:info, "#{meta.worker} job finished", duration: measure.duration)
  end

  def handle_event([:oban, :job, :exception], _measure, meta, _config) do
    # The :oban domain keeps Sentry from reporting the error a second time
    Logger.log(
      :error,
      "#{meta.worker} job error",
      error: Exception.format(meta.kind, meta.reason, meta.stacktrace),
      domain: [:oban]
    )
  end

  def handle_event(_, _, _, _), do: :ok

  defp metadata(meta) do
    [worker: meta.worker, job_id: meta.id, attempt: meta.attempt, max_attempts: meta.max_attempts]
  end
end
