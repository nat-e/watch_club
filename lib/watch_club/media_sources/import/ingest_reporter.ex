defmodule WatchClub.MediaSources.Import.IngestReporter do
  @moduledoc """
  Reports each run of a file's ingest job from its `[:watch_club, :media_ingest]` telemetry span:
  one `media_ingested` log line, and the outcome on the job's trace span. A crash is the `failed`
  outcome, logged with its error under the `:oban` domain, so Sentry reports it only through its
  Oban integration, on the job's last attempt.
  """

  alias OpenTelemetry.Tracer

  require Logger

  @doc "Attaches the handler. Call once on application start."
  def attach do
    :telemetry.attach_many(
      "watch-club-ingest-reporter",
      [[:watch_club, :media_ingest, :stop], [:watch_club, :media_ingest, :exception]],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:watch_club, :media_ingest, :stop], _measurements, metadata, _config) do
    %{path: path, outcome: outcome, reason: reason} = metadata
    set_span_attributes(metadata, outcome, reason)

    {level, message} =
      case {outcome, reason} do
        {:matched, :manual_match} ->
          {:info, "#{path} keeps its Manual Match"}

        {:matched, nil} ->
          {:info, "Matched #{path}"}

        {:unmatched, :content_not_found} ->
          {:warning, "No Content matches #{path}"}

        {:unmatched, :episode_not_listed} ->
          {:warning, "TMDB doesn't list the episode of #{path}"}

        {:unreadable, nil} ->
          {:warning, "Couldn't read #{path}: #{inspect(metadata.error)}"}
      end

    Logger.log(level, message,
      event: :media_ingested,
      outcome: outcome,
      reason: reason,
      tmdb_id: metadata[:tmdb_id],
      error: metadata[:error]
    )
  end

  def handle_event([:watch_club, :media_ingest, :exception], _measurements, metadata, _config) do
    set_span_attributes(metadata, :failed, nil)

    Logger.error("Couldn't ingest #{metadata.path}",
      event: :media_ingested,
      outcome: :failed,
      error: Exception.format(metadata.kind, metadata.reason, metadata.stacktrace),
      domain: [:oban]
    )
  end

  defp set_span_attributes(metadata, outcome, reason) do
    Tracer.set_attributes(%{
      "file.path" => metadata.path,
      "watch_club.media.type" => to_string(metadata.media_type),
      "watch_club.media_ingest.trigger" => to_string(metadata.trigger),
      "watch_club.media_ingest.outcome" => to_string(outcome),
      "watch_club.media_ingest.reason" => to_string(reason)
    })
  end
end
