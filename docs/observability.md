# Observability

WatchClub's server shows what it's doing in four ways:

- **Logs**, printed to the console
- **Traces, metrics and logs**, sent to an OpenTelemetry tool of your choice
- **Error reports**, sent to a Sentry instance of your choice
- **A health check**, for your host or uptime monitor

Only the console logs are on by default. You turn on the others with environment variables.

## Privacy

We never log IP address, email addresses or any other PII.

## Logs

The server prints its logs to the console (stdout) as plain text, in color when you view them in a terminal.

To print one JSON object per line instead, which log tools such as Loki or Datadog read without extra setup, set:

```dotenv
LOG_FORMAT=json
```

`LOG_LEVEL` sets how much the server logs: `info` by default, `debug` for more, `warn` or `error` for less.

When it starts, the server logs its version and which of the telemetry below it sends, so you can check your settings.

## OpenTelemetry

The server can send its telemetry to any tool that accepts OpenTelemetry (OTLP), such as Grafana, SigNoz, Jaeger or Sentry:

Turn on the ones you want, and say where to send them:

```dotenv
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4318
# If your tool needs a token
OTEL_EXPORTER_OTLP_HEADERS="authorization=Bearer your-token"
```

Your telemetry shows up under the name `watch_club`. Set `OTEL_SERVICE_NAME` to change it.

### Metrics

| Metric                           | What it shows                                                                   |
| -------------------------------- | ------------------------------------------------------------------------------- |
| `http.server.request.duration`   | How many requests the server answers, and how long they take                    |
| `http.server.active_requests`    | The requests the server is answering right now                                  |
| `db.client.operation.duration`   | How long database queries take                                                  |
| `db.client.connection.count`     | The database connections in use, and the idle ones                              |
| `db.client.connection.wait_time` | How long the server waits for a free database connection                        |
| `jobs.attempt.duration`          | How long background jobs take, and whether they succeed, will retry or fail     |
| `jobs.executing`                 | The background jobs running right now                                           |
| `jobs.waiting`                   | The background jobs waiting to start                                            |
| `jobs.waiting.oldest_age`        | How long the oldest waiting job has waited. If it keeps growing, jobs are stuck |

## Error reports

The server and the apps can report their errors and crashes to Sentry, or to GlitchTip or Bugsink. Set the DSN of a Sentry project for each:

```dotenv
# The server
SENTRY_DSN=https://key@o0.ingest.sentry.io/0
# The web app
SENTRY_WEB_DSN=https://key@o0.ingest.sentry.io/1
# The mobile apps
SENTRY_MOBILE_DSN=https://key@o0.ingest.sentry.io/2
# Optional: the environment all their reports name, production by default
SENTRY_ENVIRONMENT=staging
```

The apps get these settings from your server, so their reports go to your Sentry, not to us. For now, the mobile apps' crash reports don't show their source code.

## Health check

`GET /api/health` answers `200` while the server can reach its database, and `503` otherwise. Point your host's health check or your uptime monitor at it.
