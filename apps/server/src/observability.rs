//! The server's logs on the console, and, when its host turns them on, its traces, metrics and logs
//! sent to an OTLP endpoint, and its errors sent to Sentry.

use std::{
    fmt::{self, Display},
    io::{self, IsTerminal},
};

use anyhow::Context;
use axum::extract::Request;
use opentelemetry::{
    KeyValue, global,
    trace::{TraceContextExt, TracerProvider},
};
use opentelemetry_appender_tracing::layer::{OpenTelemetryTracingBridge, TracingSpanAttributes};
use opentelemetry_instrumentation_tower::http::server as otel_http;
use opentelemetry_otlp::{LogExporter, MetricExporter, SpanExporter};
use opentelemetry_sdk::{
    Resource, logs::SdkLoggerProvider, metrics::SdkMeterProvider,
    propagation::TraceContextPropagator, trace::SdkTracerProvider,
};
use opentelemetry_semantic_conventions::{
    attribute::{HTTP_REQUEST_METHOD, URL_PATH},
    resource::SERVICE_VERSION,
};
use sentry::{
    Hub, SentryFutureExt,
    integrations::{
        tower::{NewSentryLayer, SentryHttpLayer},
        tracing::{BreadcrumbLayer, ErrorLayer},
    },
    protocol::{Event, TraceContext},
};
use tower_http::trace::TraceLayer;
use tracing::Metadata;
use tracing_subscriber::{
    Layer,
    filter::{LevelFilter, filter_fn},
    layer::SubscriberExt,
    util::SubscriberInitExt,
};
use utoipa_axum::router::OpenApiRouter;

use crate::config::{LogFormat, ObservabilityConfig};

/// The name of the server's own instrumentation, apart from the libraries'
const SCOPE: &str = env!("CARGO_PKG_NAME");

/// The name of the span `instrument` gives each request, for the logs
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

    let console = match config.log_format {
        // Colors only on a terminal: Docker and log collectors would keep their codes as text. On a
        // terminal, the default also leaves them out when `NO_COLOR` is set
        LogFormat::Text if !io::stdout().is_terminal() => {
            tracing_subscriber::fmt::layer().with_ansi(false).boxed()
        }
        LogFormat::Text => tracing_subscriber::fmt::layer().boxed(),
        // The event's fields beside its message, and the fields of each span around it, from the
        // outermost
        LogFormat::Json => tracing_subscriber::fmt::layer()
            .json()
            .flatten_event(true)
            .with_current_span(false)
            .with_span_list(true)
            .boxed(),
    };

    tracing_subscriber::registry()
        .with(config.log_filter.clone())
        .with(console)
        .with(tracer_provider.as_ref().map(|provider| {
            tracing_opentelemetry::layer()
                .with_tracer(provider.tracer(SCOPE))
                // The request's span repeats the one `otel_http` exports
                .with_filter(filter_fn(|metadata| {
                    !is_from_exporter(metadata) && !is_request_span(metadata)
                }))
        }))
        .with(logger_provider.as_ref().map(|provider| {
            // With the fields of the spans around them, as the console shows them before each line
            OpenTelemetryTracingBridge::builder(provider)
                .with_tracing_span_attributes(TracingSpanAttributes::all())
                .build()
                .with_filter(filter_fn(|metadata| !is_from_exporter(metadata)))
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

/// Adds what observes each request to the routes: its span, whose method and path its logs show, its
/// trace and metrics, and its details on the errors Sentry gets. The layers the routes already have
/// run inside the request's span.
pub(crate) fn instrument<S: Clone + Send + Sync + 'static>(
    routes: OpenApiRouter<S>,
) -> OpenApiRouter<S> {
    routes
        // Shows the method and path on every log line written during a request
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(|request: &Request| {
                    // At error level, so that it holds every log of the request whatever
                    // `RUST_LOG` filters out
                    tracing::error_span!(
                        REQUEST_SPAN,
                        { HTTP_REQUEST_METHOD } = %request.method(),
                        { URL_PATH } = %request.uri().path(),
                        version = ?request.version(),
                    )
                })
                // The routes log the 500s themselves, with their cause
                .on_failure(()),
        )
        // Names the spans after the route, such as `GET /api/me`, once the router has matched it
        .layer(otel_http::Layer::new())
        .layer(SentryHttpLayer::new())
        // Outside the other Sentry layer, which needs a Sentry hub of the request's own
        .layer(NewSentryLayer::new_from_top())
}

/// Runs `task`, work apart from requests, with a Sentry scope of its own, as `instrument` gives each
/// request: the errors it reports carry `tags` and only its own breadcrumbs, and Sentry groups them
/// by their message and `group`.
pub(crate) fn with_error_scope<F: Future>(
    tags: &[(&str, &dyn Display)],
    group: &str,
    task: F,
) -> impl Future<Output = F::Output> + use<F> {
    let hub = Hub::new_from_top(Hub::current());
    hub.configure_scope(|scope| {
        for (key, value) in tags {
            scope.set_tag(key, value);
        }
        scope.set_fingerprint(Some(&["{{ default }}", group]));
    });
    task.bind_hub(hub)
}

/// Returns whether the span or event comes from the crates that export, which mustn't be exported.
fn is_from_exporter(metadata: &Metadata<'_>) -> bool {
    let target = metadata.target();
    EXPORTER_TARGETS
        .iter()
        .any(|prefix| target.starts_with(prefix))
}

/// Returns whether it's the span `instrument` gives each request.
fn is_request_span(metadata: &Metadata<'_>) -> bool {
    metadata.is_span() && metadata.name() == REQUEST_SPAN && metadata.target() == module_path!()
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
