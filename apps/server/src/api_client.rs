//! The client WatchClub calls other services' JSON APIs with, such as the Metadata Providers'.

use std::time::Duration;

use anyhow::{Context, bail};
use reqwest::{
    StatusCode, Url,
    header::{AUTHORIZATION, HeaderMap, HeaderValue},
};
use reqwest_middleware::{ClientBuilder, ClientWithMiddleware, RequestBuilder};
use reqwest_retry::{RetryTransientMiddleware, policies::ExponentialBackoff};
use reqwest_tracing::{OtelName, SpanBackendWithUrl, TracingMiddleware};
use secrecy::{ExposeSecret, SecretString};
use serde::{Serialize, de::DeserializeOwned};

/// The number of characters of a failed answer's body that its error shows
const EXCERPT_LENGTH: usize = 300;

/// The name and version that calls tell services, as they ask
const USER_AGENT: &str = concat!(env!("CARGO_PKG_NAME"), "/", env!("CARGO_PKG_VERSION"));

/// A client of another service's JSON API. Clones share their connections.
///
/// It gives up on an attempt after 10 s, and tries again up to twice, after a growing wait, when
/// the connection fails or times out, or the service answers 408, 429 or 5xx. Each attempt is a
/// span in the trace, as OpenTelemetry's HTTP conventions describe, named after the method and the
/// route, such as `GET /movie/{id}`.
#[derive(Clone, Debug)]
pub(crate) struct ApiClient {
    http: ClientWithMiddleware,
    base_url: Url,
}

impl ApiClient {
    /// Returns a client of the API at `base_url`, which signs in with `token` as a bearer token.
    pub(crate) fn new(base_url: &str, token: &SecretString) -> anyhow::Result<Self> {
        let base_url = Url::parse(base_url).with_context(|| format!("{base_url} isn't a URL"))?;
        anyhow::ensure!(!base_url.cannot_be_a_base(), "{base_url} can't have paths");

        let mut authorization = HeaderValue::try_from(format!("Bearer {}", token.expose_secret()))
            .context("the API token can't go in a header")?;
        // Keeps it out of logs and debug output
        authorization.set_sensitive(true);

        let client = reqwest::Client::builder()
            .default_headers(HeaderMap::from_iter([(AUTHORIZATION, authorization)]))
            .user_agent(USER_AGENT)
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(10))
            .build()
            .context("failed to set up an HTTP client")?;

        let retries = ExponentialBackoff::builder().build_with_max_retries(2);
        let http = ClientBuilder::new(client)
            // Around the tracing, so that each attempt has a span of its own
            .with(RetryTransientMiddleware::new_with_policy(retries))
            .with(TracingMiddleware::<SpanBackendWithUrl>::new())
            .build();

        Ok(Self { http, base_url })
    }

    /// GETs the JSON at `route`, such as `/movie/{id}`, whose `{…}` take `args` in order, escaped,
    /// or returns None when the service answers 404.
    ///
    /// # Panics
    ///
    /// When `route` has more or fewer `{…}` than `args`.
    pub(crate) async fn get<T: DeserializeOwned>(
        &self,
        route: &'static str,
        args: &[&str],
        params: &[(&str, &str)],
    ) -> anyhow::Result<Option<T>> {
        let request = self.http.get(self.url(route, args)).query(params);
        self.send(request, format!("GET {route}")).await
    }

    /// POSTs `body` as JSON to `route`, such as `/graphql`, and returns the JSON the service answers.
    pub(crate) async fn post<T: DeserializeOwned>(
        &self,
        route: &'static str,
        body: &impl Serialize,
    ) -> anyhow::Result<T> {
        let call = format!("POST {route}");
        let request = self.http.post(self.url(route, &[])).json(body);
        let host = self.host();
        self.send(request, call.clone())
            .await?
            .with_context(|| format!("{host} answered {call} with 404 Not Found"))
    }

    /// Sends the request, which `call` names in traces and errors, such as `GET /movie/{id}`, and
    /// returns the JSON the service answers, or None when it answers 404.
    async fn send<T: DeserializeOwned>(
        &self,
        request: RequestBuilder,
        call: String,
    ) -> anyhow::Result<Option<T>> {
        let host = self.host();

        let response = request
            .with_extension(OtelName(call.clone().into()))
            .send()
            .await
            .with_context(|| format!("failed to call {call} on {host}"))?;
        let status = response.status();
        let body = response
            .bytes()
            .await
            .with_context(|| format!("failed to receive {host}'s answer to {call}"))?;

        if status == StatusCode::NOT_FOUND {
            return Ok(None);
        }
        if !status.is_success() {
            // Services say what went wrong in the body
            bail!("{host} answered {call} with {status}{}", excerpt(&body));
        }

        let answer = serde_json::from_slice(&body)
            .with_context(|| format!("failed to read {host}'s answer to {call}"))?;
        Ok(Some(answer))
    }

    /// Returns the name of the service's host, for errors.
    fn host(&self) -> &str {
        self.base_url.host_str().unwrap_or_default()
    }

    /// Returns the URL of `route`, with `args` in its `{…}`.
    fn url(&self, route: &str, args: &[&str]) -> Url {
        let mut args = args.iter();
        let segments: Vec<&str> = route
            .trim_start_matches('/')
            .split('/')
            .map(|segment| {
                let is_placeholder = segment.starts_with('{') && segment.ends_with('}');
                if is_placeholder {
                    args.next()
                        .expect("the route has more `{…}` than arguments")
                } else {
                    segment
                }
            })
            .collect();
        assert!(
            args.next().is_none(),
            "the route has fewer `{{…}}` than arguments"
        );

        let mut url = self.base_url.clone();
        url.path_segments_mut()
            .expect("`new` checked that the URL can have paths")
            .pop_if_empty()
            .extend(segments);
        url
    }
}

/// Returns the start of a failed answer's body after a colon, on one line so that it can't forge
/// log lines, or nothing when the body is empty.
fn excerpt(body: &[u8]) -> String {
    let text: String = String::from_utf8_lossy(body)
        .chars()
        .take(EXCERPT_LENGTH)
        .map(|c| if c.is_control() { ' ' } else { c })
        .collect();
    let text = text.trim();

    if text.is_empty() {
        String::new()
    } else {
        format!(": {text}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn excerpt_keeps_the_start_of_the_body_on_one_line() {
        let body = format!("<html>\n<p>{}</p>\n</html>", "x".repeat(400));

        let excerpt = excerpt(body.as_bytes());

        assert_eq!(excerpt, format!(": <html> <p>{}", "x".repeat(290)));
    }

    #[test]
    fn excerpt_is_empty_for_an_empty_body() {
        assert_eq!(excerpt(b" \n"), "");
    }
}
