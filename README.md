# WatchClub

A self-hosted media server for small private groups.

> [!WARNING]
> WatchClub is in early development (alpha). Expect bugs and breaking changes between releases until 1.0.

## Install

1. Copy [`docker-compose.yml`](docker-compose.yml) and [`.env.example`](.env.example) to a folder on your server, and rename `.env.example` to `.env`.
2. Fill in `.env`, and mount your media folders in `docker-compose.yml`.
3. Run `docker compose up -d`, then open `WC_URL` to create the administrator account.

To upgrade, run `docker compose pull && docker compose up -d`. Database migrations run on start.

## Casting to a TV

The Player casts to a Chromecast or a TV with Google Cast, from Chrome on a computer or an Android phone. The TV loads WatchClub from the address the Player was opened at, so open WatchClub at an HTTPS address the TV can reach, with a trusted certificate: behind a reverse proxy with a certificate from Let's Encrypt, for example. The Player only offers casting over HTTPS.

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

All signals share the service name, app version, environment and instance identity. Override resource attributes with `OTEL_RESOURCE_ATTRIBUTES`. `OTEL_METRIC_EXPORT_INTERVAL` sets the metric export interval in milliseconds (default: 60000); VM measurements update every 5 seconds. Tracing drops health-check, LiveView long-poll and database-root traces by default, while preserving parent sampling decisions. Database spans inside request and job traces remain. Oban scheduler and maintenance plugins are not instrumented; job tracing stays enabled. `OTEL_TRACES_SAMPLER` replaces the default sampler; `OTEL_TRACES_SAMPLER_ARG` configures the selected sampler.

Metrics cover requests, database timings, jobs, job queues, VM memory and run queues. Metrics are cumulative, and duration histograms use seconds with separate buckets for database timings, jobs and other durations. Metric labels use route patterns, response statuses, worker names and queue names. The app also exposes:

- `watch_club.contents.metadata_request.count`, labelled by `served` (`stored`, `fetched`).
- `watch_club.contents.metadata_fetch.stop.count` and `.stop.duration`, labelled by `type` (`movie`, `tv_show`) and `result` (`created`, `refreshed`, `kept_stored`, `not_found`, `unavailable`). `.callers` measures callers per fetch, including crashes, by `type`; `.exception.count` counts crashes by `type`. `kept_stored` means TMDB failed but stored Content remained usable.
- `watch_club.tmdb.request.stop.count` and `.stop.duration`, labelled by `endpoint` (path templates) and `status` (`2xx`, `404`, `429`, `4xx`, `5xx`, `error`). These count each HTTP attempt, including retries, but not cache hits.
- `watch_club.media_import.match.count`, labelled by `result` (`matched`, `not_matched`, `episode_not_listed`).
- `watch_club.marker_detection.marker.count`, one per kind for each Video that detection runs on, labelled by `media_type` (`movie`, `tv_show_episode`), `kind` (`intro`, `recap`, `credits`) and `source` (`chapter`, `audio`, `none`).
- `watch_club.audio_fingerprint.fetch.count`, labelled by `cached` (`true`, `false`), and `watch_club.audio_fingerprint.compute.stop.duration`, the time to decode and fingerprint audio, labelled by `part` (`beginning`, `end`).
- `watch_club.oban.queue.available_jobs`, the jobs ready to run, and `watch_club.oban.queue.oldest_available_job_age`, how long the oldest of them has waited in seconds, labelled by `queue`. Both update every 5 seconds and read 0 for an empty queue.

Durations and callers per fetch are exported as histograms. Suggested alerts: TMDB errors or rate limiting above a threshold; Content metadata fetch failures above a threshold, including failed refreshes that kept stored Content; and a queue's `oldest_available_job_age` above the wait its jobs can tolerate.

Content pages and imported files carry their trace into metadata fetches. A caller joining another caller's fetch gets a wait span linked to that fetch. Marker detection traces have a span for each audio fingerprint they compute. Logs export only selected request, job, Content and trace metadata; metadata warnings include TMDB IDs and, for missing TV Show Episodes, local file paths, and Marker detection logs include local file paths.

The official metrics and logging SDKs are experimental. Slow log export can accumulate logs in memory, and shutdown can lose buffered logs. Request traces include paths, query strings and client IPs. Secrets in query strings, such as password-reset tokens, Invitations and the tokens of video files, show as `REDACTED`. Database spans include SQL text without bound parameter values; literal values written directly in SQL remain. Only enable export to an endpoint you trust with this data.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
