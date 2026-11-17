# WatchClub

A self-hosted media server for small private groups.

> [!WARNING]
> This branch rewrites WatchClub with an axum server in Rust, a React web app and an Expo app for phones and TVs. It doesn't do what the released app does yet: install the released app from [`main`](https://github.com/nat-e/watch_club/tree/main).

## Try the rewrite

Every change to this branch publishes the image `ghcr.io/nat-e/watch_club:rust`. It listens on port 4000 and needs a Postgres database, whose URL goes in `DATABASE_URL`:

```sh
docker run --detach --publish 4000:4000 \
  --env DATABASE_URL=postgres://user:password@host:5432/watch_club \
  ghcr.io/nat-e/watch_club:rust
```

Database migrations run on start.

## Observability

The server logs to the console, at the level `RUST_LOG` sets (`info` by default), as text, or as one JSON object per line with `LOG_FORMAT=json`, which log tools such as Loki or Datadog read without parsing rules. It logs each sign-in, each failed sign-in with the username typed, and Setup. It never logs IP addresses. It can also send its traces, metrics and logs to an OpenTelemetry (OTLP) endpoint, and report errors to Sentry. Both are off by default. `GET /api/health` answers 200 while the server reaches its database, and 503 otherwise.

### OpenTelemetry

Turn on the signals you want:

```dotenv
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
OTEL_EXPORTER_OTLP_ENDPOINT=https://telemetry.example.com
OTEL_EXPORTER_OTLP_HEADERS="authorization=Bearer your-token"
OTEL_RESOURCE_ATTRIBUTES=deployment.environment.name=production
```

Each signal accepts `otlp` or `none`, the default. `OTEL_SDK_DISABLED=true` turns all three off.

The server sends OTLP over HTTP with protobuf, usually on port 4318: it doesn't send gRPC, and ignores another `OTEL_EXPORTER_OTLP_PROTOCOL`. The endpoint is a base URL, to which it adds `/v1/traces`, `/v1/metrics` or `/v1/logs`. To send a signal elsewhere, set its full URL in `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`, `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` or `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`. Each signal also has its own `_HEADERS` and `_TIMEOUT` variables. Sentry, Grafana Alloy, SigNoz, OpenObserve, Uptrace and Jaeger receive OTLP, and so does Prometheus with `--web.enable-otlp-receiver`.

The server reports as `watch_club`, with its version: `OTEL_SERVICE_NAME` changes the name, and `OTEL_RESOURCE_ATTRIBUTES` adds attributes.

- **Traces**: one for each request, named after its route, such as `GET /api/me`, except the health check, and one for each run of a background job, named `job`, with its kind in `job.kind`. A request with a W3C `traceparent` header continues its trace. Every trace is kept unless `OTEL_TRACES_SAMPLER` and `OTEL_TRACES_SAMPLER_ARG` say otherwise.
- **Metrics**, sent every minute unless `OTEL_METRIC_EXPORT_INTERVAL` sets another interval in milliseconds:
  - `http.server.request.duration`, `http.server.active_requests`, `http.server.request.body.size` and `http.server.response.body.size`, labelled by method, route and status, except for the health check
  - `db.client.connection.count`, the database connections by state, `idle` or `used`, and `db.client.connection.max`, the most the server opens

  Prometheus-compatible backends replace dots with underscores and add unit suffixes, such as `http_server_request_duration_seconds`.
- **Logs**: the lines the console shows, with the fields of the request or job that wrote them, such as `http.request.method`, `url.path`, `job.kind` and `job.attempt`, and with its trace when traces are on.

Traces include each request's path, query string and user agent. Query parameters that usually hold credentials, such as `sig`, show as `REDACTED`. Logs include error messages. Only send them to an endpoint you trust with this data.

### Sentry

```dotenv
# The server's errors and crashes
SENTRY_DSN=https://key@o0.ingest.sentry.io/0
# The web app's errors
SENTRY_WEB_DSN=https://key@o0.ingest.sentry.io/1
# The server's environment, production by default
SENTRY_ENVIRONMENT=production
```

Set either DSN, or both. Sentry recommends a project for each, as the server and the web app are different platforms. GlitchTip and Bugsink also accept these reports.

The server reports the errors it logs and its crashes, with the request's method, its URL without the query string, and its headers, except those that hold credentials, such as cookies, or with the job's kind, ID and attempt as the tags `job.kind`, `job.id` and `job.attempt`. Each route and each kind of job has its own issues, named after it. Failures to send telemetry to the OTLP endpoint only show on the console. When traces are on, each report links to the trace of its request or job. The web app reports its errors, except failed requests to the server, which reports its own. Neither sends the IP addresses of Users.

The mobile apps we publish report their crashes and errors to our own Sentry, not yours, without the addresses of Instances or the IP addresses of Users. The image includes the web app's source maps, so Sentry can show the source of its stack traces when it can reach WatchClub.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
