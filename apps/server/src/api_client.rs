//! The client WatchClub calls other services' JSON APIs with, such as the Metadata Providers' and
//! the Sources'.

use std::time::Duration;

use anyhow::Context;
use reqwest::{
    StatusCode, Url,
    header::{AUTHORIZATION, HeaderName, HeaderValue},
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

/// The HTTP connections that the API clients share, which the server sets up once. Clones share
/// them too.
///
/// It gives up on connecting after 5 s, and on an attempt after 10 s.
#[derive(Clone, Debug)]
pub struct HttpClient(reqwest::Client);

impl HttpClient {
    /// Returns the connections, which fail to set up when the server finds no CA certificates on
    /// the system.
    pub fn new() -> anyhow::Result<Self> {
        let client = reqwest::Client::builder()
            .user_agent(USER_AGENT)
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(10))
            .build()
            .context("failed to set up the HTTP client")?;
        Ok(Self(client))
    }
}

/// A client of another service's JSON API. Clones share their connections.
///
/// Each attempt is a span in the trace, as OpenTelemetry's HTTP conventions describe, named after
/// the method and the route, such as `GET /movie/{id}`.
#[derive(Clone, Debug)]
pub(crate) struct ApiClient {
    http: ClientWithMiddleware,
    base_url: Url,
    credentials: ApiCredentials,
}

/// How a client proves who it is: the header with its secret that it adds to each request, if
/// any. Logs and debug output leave the secret out.
#[derive(Clone, Debug)]
pub(crate) struct ApiCredentials(Option<(HeaderName, HeaderValue)>);

/// The error of a secret that can't go in a header, such as one with a line break.
#[derive(Debug, thiserror::Error)]
#[error("the secret has a character that can't go in a header, such as a line break")]
pub(crate) struct ApiCredentialsError;

impl ApiCredentials {
    /// Returns no credentials, for an API that anyone can call, such as sportarr.net's.
    pub(crate) const fn anonymous() -> Self {
        Self(None)
    }

    /// Returns a token in the `Authorization: Bearer` header, as TMDB and Hardcover take.
    pub(crate) fn bearer_token(token: &SecretString) -> Result<Self, ApiCredentialsError> {
        let value = format!("Bearer {}", token.expose_secret());
        Self::secret_header(AUTHORIZATION, &value)
    }

    /// Returns a key in the `X-Api-Key` header, as Radarr, Sonarr and Sportarr take.
    pub(crate) fn api_key(key: &SecretString) -> Result<Self, ApiCredentialsError> {
        Self::secret_header(HeaderName::from_static("x-api-key"), key.expose_secret())
    }

    /// Returns the credentials that send the secret `value` in the header `name`.
    fn secret_header(name: HeaderName, value: &str) -> Result<Self, ApiCredentialsError> {
        let mut value = HeaderValue::from_str(value).map_err(|_| ApiCredentialsError)?;
        // Keeps it out of logs and debug output
        value.set_sensitive(true);
        Ok(Self(Some((name, value))))
    }
}

/// Whether a client tries a call again after a failure that may pass, which takes longer to fail.
#[derive(Clone, Copy, Debug)]
pub(crate) enum Retries {
    /// Up to twice, after a growing wait, when the connection fails or times out, or the service
    /// answers 408, 429 or 5xx
    Twice,
    /// Never, for the calls whose answer the User waits for in a form, which a wrong address would
    /// keep waiting
    Never,
}

/// The failures of a call to a service.
#[derive(Debug, thiserror::Error)]
pub(crate) enum CallError {
    /// The service didn't answer, such as when nothing listens at its address or it took too long
    #[error("failed to call {call} on {host}")]
    Unreachable {
        call: String,
        host: String,
        #[source]
        source: reqwest_middleware::Error,
    },
    /// The service answered with an error status. `get` answers None to a 404 instead
    #[error("{host} answered {call} with {status}{excerpt}")]
    Failed {
        call: String,
        host: String,
        status: StatusCode,
        /// The start of the body, where services say what went wrong
        excerpt: String,
    },
    /// The service's answer isn't the JSON that the call expects
    #[error("failed to read {host}'s answer to {call}")]
    InvalidAnswer {
        call: String,
        host: String,
        #[source]
        source: serde_json::Error,
    },
}

impl ApiClient {
    /// Returns a client of the API at `base_url`, an http or https URL, which calls it through
    /// `http_client`'s connections and proves who it is with `credentials`.
    pub(crate) fn new(
        http_client: &HttpClient,
        base_url: Url,
        credentials: ApiCredentials,
        retries: Retries,
    ) -> Self {
        let mut http = ClientBuilder::new(http_client.0.clone());
        if let Retries::Twice = retries {
            let policy = ExponentialBackoff::builder().build_with_max_retries(2);
            // Around the tracing, so that each attempt has a span of its own
            http = http.with(RetryTransientMiddleware::new_with_policy(policy));
        }
        let http = http
            .with(TracingMiddleware::<SpanBackendWithUrl>::new())
            .build();

        Self {
            http,
            base_url,
            credentials,
        }
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
    ) -> Result<Option<T>, CallError> {
        let request = self.http.get(self.url(route, args)).query(params);
        match self.send(request, format!("GET {route}")).await {
            Ok(answer) => Ok(Some(answer)),
            Err(CallError::Failed { status, .. }) if status == StatusCode::NOT_FOUND => Ok(None),
            Err(error) => Err(error),
        }
    }

    /// POSTs `body` as JSON to `route`, such as `/graphql`, and returns the JSON the service answers.
    pub(crate) async fn post<T: DeserializeOwned>(
        &self,
        route: &'static str,
        body: &impl Serialize,
    ) -> Result<T, CallError> {
        let request = self.http.post(self.url(route, &[])).json(body);
        self.send(request, format!("POST {route}")).await
    }

    /// Sends the request, which `call` names in traces and errors, such as `GET /movie/{id}`, and
    /// returns the JSON the service answers.
    async fn send<T: DeserializeOwned>(
        &self,
        request: RequestBuilder,
        call: String,
    ) -> Result<T, CallError> {
        let host = self.host().to_owned();

        let mut request = request.with_extension(OtelName(call.clone().into()));
        if let Some((name, value)) = &self.credentials.0 {
            request = request.header(name.clone(), value.clone());
        }
        let response = match request.send().await {
            Ok(response) => response,
            Err(source) => return Err(CallError::Unreachable { call, host, source }),
        };
        let status = response.status();
        let body = match response.bytes().await {
            Ok(body) => body,
            // Such as when the service stops in the middle of its answer
            Err(error) => {
                let source = error.into();
                return Err(CallError::Unreachable { call, host, source });
            }
        };

        if !status.is_success() {
            let excerpt = excerpt(&body);
            return Err(CallError::Failed {
                call,
                host,
                status,
                excerpt,
            });
        }

        serde_json::from_slice(&body).map_err(|source| CallError::InvalidAnswer {
            call,
            host,
            source,
        })
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
            .expect("the API's URL is an http or https URL, which can have paths")
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
