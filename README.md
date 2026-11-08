# WatchClub

A self-hosted media server for small private groups.

> [!WARNING]
> WatchClub is in early development (alpha). Expect bugs and breaking changes between releases until 1.0.

## Install

1. Copy [`docker-compose.yml`](docker-compose.yml) and [`.env.example`](.env.example) to a folder on your server, and rename `.env.example` to `.env`.
2. Fill in `.env`, and mount your media folders in `docker-compose.yml`.
3. Run `docker compose up -d`, then open `WC_URL` to create the administrator account.

To upgrade, run `docker compose pull && docker compose up -d`. Database migrations run on start.

## OpenTelemetry

WatchClub can push traces, metrics and logs directly to your OTLP endpoint. Export is off by default. Enable the signals you want in `.env`, then restart the app:

```dotenv
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
OTEL_EXPORTER_OTLP_ENDPOINT=https://telemetry.example.com
OTEL_EXPORTER_OTLP_HEADERS="authorization=Bearer your-token"
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_SERVICE_NAME=watch_club
OTEL_RESOURCE_ATTRIBUTES=deployment.environment.name=production
```

Each signal accepts `otlp` or `none`. `OTEL_SDK_DISABLED=true` disables all three. Console logging and Sentry keep their own settings.

The shared endpoint is a base URL: HTTP export appends `/v1/traces`, `/v1/metrics` or `/v1/logs`. For separate destinations, use `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`, `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` and `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` with their full paths. Each signal also supports its own `_HEADERS` and `_PROTOCOL` variables. The SDK supports HTTP/protobuf and gRPC. See the [official exporter documentation](https://opentelemetry.io/docs/languages/erlang/exporters/).

All signals share the service name, app version, environment and instance identity. Override resource attributes with `OTEL_RESOURCE_ATTRIBUTES`. `OTEL_METRIC_EXPORT_INTERVAL` sets the metric export interval in milliseconds (default: 60000); VM measurements update every 5 seconds. Tracing uses the SDK's sampling settings, including `OTEL_TRACES_SAMPLER` and `OTEL_TRACES_SAMPLER_ARG`.

Metrics cover requests, database timings, jobs, VM memory and run queues. Metric labels use route patterns, response statuses, worker names and queue names. Logs keep their existing messages and export only selected request, job and trace metadata.

The official metrics and logging SDKs are experimental. Slow log export can accumulate logs in memory, and shutdown can lose buffered logs. Request traces include raw paths, query strings and client IPs, including password-reset tokens and Invitation codes. Database work outside a request or job creates separate traces. Only enable export to an endpoint you trust with this data.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
