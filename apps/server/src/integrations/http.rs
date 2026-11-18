//! The HTTP client the integrations call other services with.

use std::time::Duration;

use anyhow::Context;
use reqwest::header::HeaderMap;
use reqwest_middleware::{ClientBuilder, ClientWithMiddleware};
use reqwest_retry::{RetryTransientMiddleware, policies::ExponentialBackoff};
use reqwest_tracing::{SpanBackendWithUrl, TracingMiddleware};

/// Returns a client that sends `headers` with every call, such as its credentials. It gives up on
/// an attempt after 10 s, and tries again up to twice, after a growing wait, when the connection
/// fails or times out, or the service answers 408, 429 or 5xx. It tries again whatever the method,
/// so use it for calls that are safe to repeat.
///
/// Each attempt is a span in the trace, as OpenTelemetry's HTTP conventions describe. Name a call's
/// spans after its method and the template of its path, such as `GET /movie/{id}`, with the
/// `reqwest_tracing::OtelName` extension.
pub(super) fn client(headers: HeaderMap) -> anyhow::Result<ClientWithMiddleware> {
    let client = reqwest::Client::builder()
        .default_headers(headers)
        .user_agent(concat!(
            env!("CARGO_PKG_NAME"),
            "/",
            env!("CARGO_PKG_VERSION")
        ))
        .connect_timeout(Duration::from_secs(5))
        .timeout(Duration::from_secs(10))
        .build()
        .context("failed to set up an HTTP client")?;
    let retries = ExponentialBackoff::builder().build_with_max_retries(2);
    Ok(ClientBuilder::new(client)
        // Around the tracing, so that each attempt has a span of its own
        .with(RetryTransientMiddleware::new_with_policy(retries))
        .with(TracingMiddleware::<SpanBackendWithUrl>::new())
        .build())
}
