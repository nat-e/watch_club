//! The HTTP client the integrations call other services with, and what observes each call: a span
//! in the trace, and the `http.client.request.duration` metric, as OpenTelemetry's HTTP conventions
//! describe them.

use std::{
    sync::LazyLock,
    time::{Duration, Instant},
};

use anyhow::Context;
use bytes::Bytes;
use opentelemetry::{
    KeyValue, global,
    metrics::Histogram,
    trace::{Span, SpanKind, Status, Tracer},
};
use opentelemetry_semantic_conventions::{
    attribute::{
        ERROR_TYPE, HTTP_REQUEST_METHOD, HTTP_RESPONSE_STATUS_CODE, SERVER_ADDRESS, SERVER_PORT,
        URL_FULL, URL_TEMPLATE,
    },
    metric::HTTP_CLIENT_REQUEST_DURATION,
};
use reqwest::{Client, Method, Request, StatusCode, Url, header::HeaderMap, retry};

/// The name of the server's own instrumentation, as in `observability`
const SCOPE: &str = env!("CARGO_PKG_NAME");

/// Returns a client for the service at `base_url`, which sends `headers` with every call, such as
/// its credentials. It gives up on a call after 10 s, and sends a GET again at once, up to twice,
/// when the connection fails or the service answers 502, 503 or 504, which tend to pass.
pub(super) fn client(base_url: &Url, headers: HeaderMap) -> anyhow::Result<Client> {
    let host = base_url
        .host_str()
        .context("the URL has no host")?
        .to_owned();
    let retries = retry::for_host(host).classify_fn(|attempt| {
        let passing = match attempt.status() {
            Some(status) => matches!(
                status,
                StatusCode::BAD_GATEWAY
                    | StatusCode::SERVICE_UNAVAILABLE
                    | StatusCode::GATEWAY_TIMEOUT
            ),
            None => attempt
                .error()
                .and_then(|error| error.downcast_ref::<reqwest::Error>())
                .is_some_and(reqwest::Error::is_connect),
        };
        if passing && attempt.method() == Method::GET {
            attempt.retryable()
        } else {
            attempt.success()
        }
    });
    Client::builder()
        .default_headers(headers)
        .user_agent(concat!(
            env!("CARGO_PKG_NAME"),
            "/",
            env!("CARGO_PKG_VERSION")
        ))
        .connect_timeout(Duration::from_secs(5))
        .timeout(Duration::from_secs(10))
        .retry(retries)
        .build()
        .context("failed to set up an HTTP client")
}

/// A service's answer: its status and its body.
pub(super) struct Answer {
    pub status: StatusCode,
    pub body: Bytes,
}

/// Sends the request with the client and reads the answer, in a span named after its method and
/// `route`, the template of its path, such as `/movie/{id}`. The span shows the URL, and with the
/// metric, the status and the type of the failure, if any.
pub(super) async fn send(
    client: &Client,
    request: Request,
    route: &'static str,
) -> reqwest::Result<Answer> {
    let url = request.url();
    let mut attributes = vec![
        KeyValue::new(HTTP_REQUEST_METHOD, request.method().to_string()),
        KeyValue::new(
            SERVER_ADDRESS,
            url.host_str().unwrap_or_default().to_owned(),
        ),
        KeyValue::new(URL_TEMPLATE, route),
    ];
    if let Some(port) = url.port_or_known_default() {
        attributes.push(KeyValue::new(SERVER_PORT, i64::from(port)));
    }
    let tracer = global::tracer(SCOPE);
    let mut span = tracer
        .span_builder(format!("{} {route}", request.method()))
        .with_kind(SpanKind::Client)
        .with_attributes(
            attributes
                .iter()
                .cloned()
                .chain([KeyValue::new(URL_FULL, url.to_string())]),
        )
        .start(&tracer);

    let started = Instant::now();
    // The status, once the answer starts, and the answer, once its body is read
    let (status, result) = match client.execute(request).await {
        Ok(response) => {
            let status = response.status();
            let body = response.bytes().await;
            (Some(status), body.map(|body| Answer { status, body }))
        }
        Err(error) => (None, Err(error)),
    };
    let duration = started.elapsed().as_secs_f64();

    let mut outcome = Vec::with_capacity(2);
    if let Some(status) = status {
        outcome.push(KeyValue::new(
            HTTP_RESPONSE_STATUS_CODE,
            i64::from(status.as_u16()),
        ));
    }
    match (&result, status) {
        (Err(error), _) => {
            outcome.push(KeyValue::new(ERROR_TYPE, error_type(error)));
            span.set_status(Status::error(format!("{error:#}")));
        }
        (Ok(_), Some(status)) if status.is_client_error() || status.is_server_error() => {
            outcome.push(KeyValue::new(ERROR_TYPE, status.as_str().to_owned()));
            span.set_status(Status::error(status.to_string()));
        }
        (Ok(_), _) => {}
    }
    span.set_attributes(outcome.iter().cloned());
    span.end();
    attributes.extend(outcome);
    DURATION.record(duration, &attributes);
    result
}

/// Returns the kind of a failure to get an answer or read it, for `error.type`.
fn error_type(error: &reqwest::Error) -> &'static str {
    if error.is_timeout() {
        "timeout"
    } else if error.is_connect() {
        "connect"
    } else if error.is_body() || error.is_decode() {
        "body"
    } else {
        "_OTHER"
    }
}

/// The time each call takes, made on first use, once `observability::start` has set where metrics
/// go.
static DURATION: LazyLock<Histogram<f64>> = LazyLock::new(|| {
    global::meter(SCOPE)
        .f64_histogram(HTTP_CLIENT_REQUEST_DURATION)
        .with_unit("s")
        .with_description("The time each call to another service takes.")
        // OpenTelemetry's advice for this metric, as the default buckets suit milliseconds
        .with_boundaries(vec![
            0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0,
        ])
        .build()
});
