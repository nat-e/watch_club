//! The server's logs on the console, and, when its host turns them on, its traces, metrics and logs
//! sent to an OTLP endpoint, and its errors sent to Sentry.

use std::fmt;

use anyhow::Context;
use axum::{extract::Request, middleware};
use opentelemetry::{
    InstrumentationScope, KeyValue, global,
    trace::{TraceContextExt, TracerProvider},
};
use opentelemetry_appender_tracing::layer::OpenTelemetryTracingBridge;
use opentelemetry_instrumentation_tower::http::server as otel_http;
use opentelemetry_otlp::{LogExporter, MetricExporter, SpanExporter};
use opentelemetry_sdk::{
    Resource, logs::SdkLoggerProvider, metrics::SdkMeterProvider,
    propagation::TraceContextPropagator, trace::SdkTracerProvider,
};
use opentelemetry_semantic_conventions::{
    attribute::{DB_CLIENT_CONNECTION_POOL_NAME, DB_CLIENT_CONNECTION_STATE},
    metric::{DB_CLIENT_CONNECTION_COUNT, DB_CLIENT_CONNECTION_MAX},
    resource::SERVICE_VERSION,
};
use sentry::{
    integrations::{
        tower::{NewSentryLayer, SentryHttpLayer},
        tracing::{BreadcrumbLayer, ErrorLayer},
    },
    protocol::{Event, TraceContext},
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
use utoipa_axum::router::OpenApiRouter;

use crate::{config::ObservabilityConfig, error};

/// The name of the server's own instrumentation, apart from the libraries'
const SCOPE: &str = env!("CARGO_PKG_NAME");

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
    sentry: Option<sentry::ClientInitGuard>,
}

impl fmt::Debug for Observability {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Observability")
            .field("exports_traces", &self.tracer_provider.is_some())
            .field("exports_metrics", &self.meter_provider.is_some())
            .field("exports_logs", &self.logger_provider.is_some())
            .field("reports_to_sentry", &self.sentry.is_some())
            .finish()
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

/// Starts the observability the settings turn on, and logs to the console. Call it before starting
/// the async runtime, as Sentry needs, and before building the router.
pub fn start(config: &ObservabilityConfig) -> anyhow::Result<Observability> {
    let resource = Resource::builder()
        .with_service_name(config.service_name.clone())
        .with_attribute(KeyValue::new(SERVICE_VERSION, env!("CARGO_PKG_VERSION")))
        .build();
    let tracer_provider = if config.exports.traces {
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
    let meter_provider = if config.exports.metrics {
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
    let logger_provider = if config.exports.logs {
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

    let sentry = config.sentry_dsn.clone().map(|dsn| {
        sentry::init((
            dsn,
            sentry::ClientOptions::new()
                .maybe_release(sentry::release_name!())
                .before_send(|event| Some(link_to_trace(event))),
        ))
    });

    tracing_subscriber::registry()
        .with(EnvFilter::new(&config.log_filter))
        .with(tracing_subscriber::fmt::layer())
        .with(tracer_provider.as_ref().map(|provider| {
            tracing_opentelemetry::layer()
                .with_tracer(provider.tracer(SCOPE))
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
        sentry,
    })
}

/// Adds what observes each request to the routes: its span on the console logs, the log of its
/// internal error, its trace and metrics, and its details on the errors Sentry gets.
pub(crate) fn instrument<S: Clone + Send + Sync + 'static>(
    routes: OpenApiRouter<S>,
) -> OpenApiRouter<S> {
    routes
        .layer(middleware::from_fn(error::log_internal_errors))
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
    let meter = global::meter_with_scope(InstrumentationScope::builder(SCOPE).build());

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
