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
    :status,
    :worker,
    :job_id,
    :attempt,
    :max_attempts,
    :duration
  ]

  def setup! do
    signals = Application.fetch_env!(:watch_club, :opentelemetry)

    if signals[:traces] do
      :ok = OpentelemetryBandit.setup()
      :ok = OpentelemetryPhoenix.setup(adapter: :bandit, liveview: true)
      # The dependency otherwise includes the database URL's credentials.
      :ok =
        OpentelemetryEcto.setup([:watch_club, :repo],
          additional_attributes: %{:"db.url" => ""}
        )

      :ok = OpentelemetryOban.setup()
    end

    if signals[:logs] do
      :ok =
        :logger.add_handler(:watch_club_otel, :otel_log_handler, %{
          filters: [metadata: {&__MODULE__.filter_log/2, []}],
          exporter: {:otel_exporter_logs_otlp, %{protocol: :http_protobuf}}
        })
    end

    :ok
  end

  def filter_log(%{meta: metadata} = event, _config) do
    %{event | meta: Map.take(metadata, @log_metadata)}
  end
end
