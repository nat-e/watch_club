//! The client WatchClub calls other services' JSON APIs with, such as the Metadata Providers' and
//! the Sources'. It calls once: callers decide whether to try again, as the jobs do. Its calls
//! fail with reqwest's errors, whose `status()` and `is_timeout()` tell callers what went wrong.

use std::{
    fmt::{self, Display, Formatter},
    str::FromStr,
    time::Duration,
};

use anyhow::Context;
use reqwest::{
    Response, StatusCode, Url,
    header::{AUTHORIZATION, HeaderName, HeaderValue},
};
use reqwest_middleware::{ClientBuilder, ClientWithMiddleware, RequestBuilder};
use reqwest_tracing::{OtelName, SpanBackendWithUrl, TracingMiddleware};
use secrecy::{ExposeSecret, SecretString};
use serde::{Serialize, de::DeserializeOwned};

/// The name and version that calls tell services, as they ask
const USER_AGENT: &str = concat!(env!("CARGO_PKG_NAME"), "/", env!("CARGO_PKG_VERSION"));

/// The HTTP connections that the API clients share, which the server sets up once. Clones share
/// them too.
///
/// It gives up on connecting after 5 s, and on a call after 10 s.
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

/// The address of an API, or of an app with its API under it: a URL that can have a path, which
/// the client adds each call's route to. Such as `http://radarr:7878`, but not `radarr:7878`, whose
/// scheme is `radarr`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ApiUrl(Url);

/// The error of text that isn't a URL that can have a path.
#[derive(Debug, thiserror::Error)]
#[error("the text isn't a URL that can have a path")]
pub struct ApiUrlError;

impl ApiUrl {
    /// Returns the URL with these segments added to its path, such as `["api", "v3"]` to
    /// `http://media.local/radarr`.
    #[must_use]
    pub fn join<S: AsRef<str>>(&self, segments: impl IntoIterator<Item = S>) -> Self {
        let mut url = self.0.clone();
        url.path_segments_mut()
            .expect("an `ApiUrl` can have a path")
            .pop_if_empty()
            .extend(segments);
        Self(url)
    }

    pub fn as_str(&self) -> &str {
        self.0.as_str()
    }
}

impl FromStr for ApiUrl {
    type Err = ApiUrlError;

    fn from_str(text: &str) -> Result<Self, Self::Err> {
        let url = Url::parse(text).map_err(|_| ApiUrlError)?;
        if url.cannot_be_a_base() {
            return Err(ApiUrlError);
        }
        Ok(Self(url))
    }
}

impl Display for ApiUrl {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// A client of another service's JSON API. Clones share their connections.
///
/// Each call is a span in the trace, as OpenTelemetry's HTTP conventions describe, named after
/// the method and the route, such as `GET /movie/{id}`.
#[derive(Clone, Debug)]
pub(crate) struct ApiClient {
    http: ClientWithMiddleware,
    base_url: ApiUrl,
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

impl ApiClient {
    /// Returns a client of the API at `base_url`, which calls it through `http_client`'s
    /// connections and proves who it is with `credentials`.
    pub(crate) fn new(
        http_client: &HttpClient,
        base_url: ApiUrl,
        credentials: ApiCredentials,
    ) -> Self {
        let http = ClientBuilder::new(http_client.0.clone())
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
    ) -> Result<Option<T>, reqwest::Error> {
        let request = self.http.get(self.url(route, args)).query(params);
        let response = self.send(request, format!("GET {route}")).await?;
        if response.status() == StatusCode::NOT_FOUND {
            return Ok(None);
        }
        response.error_for_status()?.json().await.map(Some)
    }

    /// GETs the JSON at `route`, like `get`, but fails when the service answers 404, as for what it
    /// always has, such as a list.
    ///
    /// # Panics
    ///
    /// When `route` has more or fewer `{…}` than `args`.
    pub(crate) async fn get_required<T: DeserializeOwned>(
        &self,
        route: &'static str,
        args: &[&str],
        params: &[(&str, &str)],
    ) -> Result<T, reqwest::Error> {
        let request = self.http.get(self.url(route, args)).query(params);
        let response = self.send(request, format!("GET {route}")).await?;
        response.error_for_status()?.json().await
    }

    /// POSTs `body` as JSON to `route`, such as `/graphql`, and returns the JSON the service answers.
    pub(crate) async fn post<T: DeserializeOwned>(
        &self,
        route: &'static str,
        body: &impl Serialize,
    ) -> Result<T, reqwest::Error> {
        let request = self.http.post(self.url(route, &[])).json(body);
        let response = self.send(request, format!("POST {route}")).await?;
        response.error_for_status()?.json().await
    }

    /// Sends the request with the client's credentials, which `call` names in traces, such as
    /// `GET /movie/{id}`.
    async fn send(
        &self,
        request: RequestBuilder,
        call: String,
    ) -> Result<Response, reqwest::Error> {
        let mut request = request.with_extension(OtelName(call.into()));
        if let Some((name, value)) = &self.credentials.0 {
            request = request.header(name.clone(), value.clone());
        }

        request.send().await.map_err(|error| match error {
            reqwest_middleware::Error::Reqwest(error) => error,
            reqwest_middleware::Error::Middleware(error) => {
                unreachable!(
                    "the tracing middleware, the only one, fails with reqwest's errors: {error:#}"
                )
            }
        })
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

        self.base_url.join(segments).0
    }
}
