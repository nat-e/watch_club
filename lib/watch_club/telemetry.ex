defmodule WatchClub.Telemetry do
  @moduledoc false

  @log_metadata [
    :time,
    :mfa,
    :otel_scope,
    :otel_trace_id,
    :otel_span_id,
    :otel_trace_flags,
    :request_id,
    :event,
    :content_type,
    :tmdb_id,
    :path,
    :media_type,
    :media_source_id,
    :media_import_id,
    :trigger,
    :outcome,
    :reason,
    :status,
    :error,
    :worker,
    :job_id,
    :attempt,
    :max_attempts,
    :duration
  ]

  def setup! do
    signals = Application.fetch_env!(:watch_club, :opentelemetry)

    if signals[:traces] do
      case OpentelemetryBandit.setup() do
        :ok -> :ok
        {:error, :already_exists} -> :ok
      end

      :ok = OpentelemetryPhoenix.setup(adapter: :bandit, liveview: true)

      # The dependency otherwise includes the database URL's credentials.
      case OpentelemetryEcto.setup([:watch_club, :repo],
             db_statement: :enabled,
             additional_attributes: %{:"db.url" => ""}
           ) do
        :ok -> :ok
        {:error, :already_exists} -> :ok
      end

      :ok = OpentelemetryOban.setup(plugin: :disabled)
    end

    if signals[:logs] do
      case :logger.add_handler(:watch_club_otel, :otel_log_handler, %{
             filters: [metadata: {&__MODULE__.filter_log/2, []}],
             exporter: {:otel_exporter_logs_otlp, %{protocol: :http_protobuf}}
           }) do
        :ok -> :ok
        {:error, {:already_exist, :watch_club_otel}} -> :ok
      end
    end

    :ok
  end

  def filter_log(%{meta: metadata} = event, _config) do
    %{event | meta: Map.take(metadata, @log_metadata)}
  end
end
