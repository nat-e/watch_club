//! What the server tells the people who host it: logs on the console, and, when they turn them on
//! with environment variables, traces, metrics and logs sent to an OTLP endpoint, and errors sent
//! to Sentry.
//!
//! OpenTelemetry follows its standard variables, such as `OTEL_EXPORTER_OTLP_ENDPOINT`, except that
//! each signal stays off until `OTEL_{TRACES,METRICS,LOGS}_EXPORTER` is `otlp`. Sentry reports the
//! server's errors to `SENTRY_DSN`, and the web app's to `SENTRY_WEB_DSN`.

use std::env;

use anyhow::{Context, bail};
use axum::{Router, extract::Request};
use opentelemetry::{
    InstrumentationScope, KeyValue, global,
    trace::{TraceContextExt, TracerProvider},
};
use opentelemetry_appender_tracing::layer::OpenTelemetryTracingBridge;
use opentelemetry_instrumentation_tower::http::server as otel_http;
use opentelemetry_otlp::{LogExporter, MetricExporter, SpanExporter};
use opentelemetry_sdk::{
    Resource,
    logs::SdkLoggerProvider,
    metrics::SdkMeterProvider,
    propagation::TraceContextPropagator,
    resource::{EnvResourceDetector, TelemetryResourceDetector},
    trace::SdkTracerProvider,
};
use opentelemetry_semantic_conventions::{
    attribute::{DB_CLIENT_CONNECTION_POOL_NAME, DB_CLIENT_CONNECTION_STATE},
    metric::{DB_CLIENT_CONNECTION_COUNT, DB_CLIENT_CONNECTION_MAX},
    resource::{SERVICE_NAME, SERVICE_VERSION},
};
use sentry::{
    integrations::{
        tower::{NewSentryLayer, SentryHttpLayer},
        tracing::{BreadcrumbLayer, ErrorLayer},
    },
    protocol::{Event, TraceContext},
    types::Dsn,
};
use sqlx::PgPool;
use tower_http::trace::TraceLayer;
use tracing::Metadata;
use tracing_subscriber::{
    EnvFilter, Layer,
    filter::{LevelFilter, filter_fn},
    layer::SubscriberExt,
    util::SubscriberInitExt,
};

/// The name the server reports under, unless `OTEL_SERVICE_NAME` changes it
const SERVICE: &str = "watch_club";

/// The name of the span `instrument` gives each request, for the console logs
const REQUEST_SPAN: &str = "request";

/// The crates that send what OpenTelemetry exports. Exporting their own logs and spans would make
/// each export start another one.
const EXPORTER_TARGETS: [&str; 5] = ["opentelemetry", "reqwest", "hyper", "h2", "rustls"];

/// The observability the host turned on. Dropping it sends what's left, so keep it until the
/// server stops.
pub struct Observability {
    tracer_provider: Option<SdkTracerProvider>,
    meter_provider: Option<SdkMeterProvider>,
    logger_provider: Option<SdkLoggerProvider>,
    _sentry: Option<sentry::ClientInitGuard>,
    web_sentry_dsn: Option<String>,
}

impl Observability {
    /// Returns the Sentry DSN the web app reports its errors to, if the host set one.
    pub fn web_sentry_dsn(&self) -> Option<String> {
        self.web_sentry_dsn.clone()
    }
}

impl Drop for Observability {
    fn drop(&mut self) {
        let results = [
            self.tracer_provider
                .as_ref()
                .map(SdkTracerProvider::shutdown),
            self.meter_provider.as_ref().map(SdkMeterProvider::shutdown),
            self.logger_provider
                .as_ref()
                .map(SdkLoggerProvider::shutdown),
        ];
        for error in results.into_iter().flatten().filter_map(Result::err) {
            tracing::warn!(
                name: "observability.shutdown.failed",
                %error,
                "failed to send the last telemetry",
            );
        }
    }
}

/// Starts the observability the environment variables turn on, and logs to the console. Call it
/// before starting the async runtime, as Sentry needs, and before building the router.
pub fn start() -> anyhow::Result<Observability> {
    let disabled =
        env::var("OTEL_SDK_DISABLED").is_ok_and(|value| value.eq_ignore_ascii_case("true"));
    let exports_traces = !disabled && exports("TRACES")?;
    let exports_metrics = !disabled && exports("METRICS")?;
    let exports_logs = !disabled && exports("LOGS")?;
    let server_sentry_dsn = sentry_dsn("SENTRY_DSN")?;
    let web_sentry_dsn = sentry_dsn("SENTRY_WEB_DSN")?;

    let resource = resource();
    let tracer_provider = if exports_traces {
        let exporter = SpanExporter::builder()
            .with_http()
            .build()
            .context("failed to set up trace export")?;
        let provider = SdkTracerProvider::builder()
            .with_batch_exporter(exporter)
            .with_resource(resource.clone())
            .build();
        global::set_tracer_provider(provider.clone());
        // Continues the traces of requests that carry a `traceparent` header
        global::set_text_map_propagator(TraceContextPropagator::new());
        Some(provider)
    } else {
        None
    };
    let meter_provider = if exports_metrics {
        let exporter = MetricExporter::builder()
            .with_http()
            .build()
            .context("failed to set up metric export")?;
        let provider = SdkMeterProvider::builder()
            .with_periodic_exporter(exporter)
            .with_resource(resource.clone())
            .build();
        global::set_meter_provider(provider.clone());
        Some(provider)
    } else {
        None
    };
    let logger_provider = if exports_logs {
        let exporter = LogExporter::builder()
            .with_http()
            .build()
            .context("failed to set up log export")?;
        let provider = SdkLoggerProvider::builder()
            .with_batch_exporter(exporter)
            .with_resource(resource)
            .build();
        Some(provider)
    } else {
        None
    };

    let sentry = server_sentry_dsn.map(|dsn| {
        sentry::init(
            sentry::ClientOptions::new()
                .dsn(&dsn)
                .maybe_release(sentry::release_name!())
                .before_send(|event| Some(link_to_trace(event))),
        )
    });

    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with(tracing_subscriber::fmt::layer())
        .with(tracer_provider.as_ref().map(|provider| {
            tracing_opentelemetry::layer()
                .with_tracer(provider.tracer(SERVICE))
                .with_filter(filter_fn(is_exported))
        }))
        .with(logger_provider.as_ref().map(|provider| {
            OpenTelemetryTracingBridge::new(provider).with_filter(filter_fn(is_exported))
        }))
        .with(sentry.is_some().then(|| {
            ErrorLayer::new()
                .with_filter(LevelFilter::ERROR)
                .and_then(BreadcrumbLayer::new().with_filter(LevelFilter::INFO))
        }))
        .try_init()
        .context("failed to set up logging")?;

    Ok(Observability {
        tracer_provider,
        meter_provider,
        logger_provider,
        _sentry: sentry,
        web_sentry_dsn,
    })
}

/// Adds what observes each request to the router: its span on the console logs, its trace and
/// metrics, and its details on the errors Sentry gets.
pub(crate) fn instrument<S: Clone + Send + Sync + 'static>(router: Router<S>) -> Router<S> {
    router
        // Shows the method and path on every log line written during a request
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(|request: &Request| {
                    tracing::info_span!(
                        REQUEST_SPAN,
                        method = %request.method(),
                        uri = %request.uri(),
                        version = ?request.version(),
                    )
                })
                // `error::log_internal_errors` logs the 500s, with their cause
                .on_failure(()),
        )
        // Names the spans after the route, such as `GET /api/me`, once the router has matched it
        .layer(otel_http::Layer::new())
        .layer(SentryHttpLayer::new())
        // Outside the other Sentry layer, which needs a Sentry hub of the request's own
        .layer(NewSentryLayer::new_from_top())
}

/// Reports the database's connections in metrics: how many are used and idle, and the most the
/// pool opens.
pub fn observe_pool(db: &PgPool) {
    let options = db.connect_options();
    // The name the conventions give a pool that has none
    let pool_name = KeyValue::new(
        DB_CLIENT_CONNECTION_POOL_NAME,
        format!(
            "{}:{}/{}",
            options.get_host(),
            options.get_port(),
            options.get_database().unwrap_or_default(),
        ),
    );
    let meter = global::meter_with_scope(InstrumentationScope::builder(SERVICE).build());

    let pool = db.clone();
    let name = pool_name.clone();
    meter
        .i64_observable_up_down_counter(DB_CLIENT_CONNECTION_COUNT)
        .with_unit("{connection}")
        .with_description("The connections to the database, by state.")
        .with_callback(move |observer| {
            let size = i64::from(pool.size());
            let idle = i64::try_from(pool.num_idle()).unwrap_or(i64::MAX).min(size);
            for (state, count) in [("idle", idle), ("used", size - idle)] {
                observer.observe(
                    count,
                    &[
                        name.clone(),
                        KeyValue::new(DB_CLIENT_CONNECTION_STATE, state),
                    ],
                );
            }
        })
        .build();

    let max = i64::from(db.options().get_max_connections());
    meter
        .i64_observable_up_down_counter(DB_CLIENT_CONNECTION_MAX)
        .with_unit("{connection}")
        .with_description("The most connections the pool opens to the database.")
        .with_callback(move |observer| observer.observe(max, std::slice::from_ref(&pool_name)))
        .build();
}

/// Returns whether the host turned the signal on with `OTEL_{signal}_EXPORTER`. It's off by
/// default, unlike the standard's `otlp`, so the server sends nothing unless asked.
fn exports(signal: &str) -> anyhow::Result<bool> {
    let variable = format!("OTEL_{signal}_EXPORTER");
    match env::var(&variable).unwrap_or_default().as_str() {
        "" | "none" => Ok(false),
        "otlp" => {
            check_protocol(signal)?;
            Ok(true)
        }
        other => bail!("{variable} must be otlp or none, not {other}"),
    }
}

/// Fails unless the signal's protocol is `http/protobuf`, the only one the server is built with.
/// The exporter would otherwise fall back to it with a warning nobody sees, before logging starts.
fn check_protocol(signal: &str) -> anyhow::Result<()> {
    for variable in [
        format!("OTEL_EXPORTER_OTLP_{signal}_PROTOCOL"),
        "OTEL_EXPORTER_OTLP_PROTOCOL".to_owned(),
    ] {
        let protocol = env::var(&variable).unwrap_or_default();
        if protocol.eq_ignore_ascii_case("http/protobuf") {
            return Ok(());
        }
        if !protocol.is_empty() {
            bail!(
                "{variable} must be http/protobuf, the only protocol WatchClub sends, not {protocol}"
            );
        }
    }
    Ok(())
}

/// Returns what every signal says about the server: its name and version, and the attributes in
/// `OTEL_RESOURCE_ATTRIBUTES`. `OTEL_SERVICE_NAME` overrides the name.
fn resource() -> Resource {
    let resource = Resource::builder_empty()
        .with_attributes([
            KeyValue::new(SERVICE_NAME, SERVICE),
            KeyValue::new(SERVICE_VERSION, env!("CARGO_PKG_VERSION")),
        ])
        .with_detectors(&[
            Box::new(TelemetryResourceDetector),
            Box::new(EnvResourceDetector::new()),
        ]);
    match env::var("OTEL_SERVICE_NAME") {
        Ok(name) if !name.is_empty() => resource.with_service_name(name),
        _ => resource,
    }
    .build()
}

/// Returns the Sentry DSN in the environment variable, or None when it's unset or empty.
fn sentry_dsn(variable: &str) -> anyhow::Result<Option<String>> {
    let dsn = env::var(variable).unwrap_or_default();
    if dsn.is_empty() {
        return Ok(None);
    }
    dsn.parse::<Dsn>()
        .with_context(|| format!("{variable} isn't a Sentry DSN"))?;
    Ok(Some(dsn))
}

/// Returns whether the OpenTelemetry layers export what the span or event describes: not what the
/// exporters do themselves, nor the console's span for each request, which repeats the trace's.
fn is_exported(metadata: &Metadata<'_>) -> bool {
    let target = metadata.target();
    let from_exporter = EXPORTER_TARGETS
        .iter()
        .any(|prefix| target.starts_with(prefix));
    let request_span =
        metadata.is_span() && metadata.name() == REQUEST_SPAN && target == module_path!();
    !from_exporter && !request_span
}

/// Points the Sentry event at the trace of the request that sent it, when the trace is exported.
fn link_to_trace(mut event: Event<'static>) -> Event<'static> {
    let context = opentelemetry::Context::current();
    let span = context.span();
    let span_context = span.span_context();
    if span_context.is_sampled() {
        let trace = TraceContext {
            trace_id: span_context.trace_id().to_bytes().into(),
            span_id: span_context.span_id().to_bytes().into(),
            ..TraceContext::default()
        };
        event.contexts.insert("trace".to_owned(), trace.into());
    }
    event
}
