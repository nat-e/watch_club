//! A client for the API's tests, which sends requests to the app's router without a server.

use std::collections::BTreeMap;

use axum::{
    Router,
    body::Body,
    http::{
        HeaderMap, HeaderValue, Method, Request, StatusCode,
        header::{AUTHORIZATION, CONTENT_TYPE, COOKIE, SET_COOKIE},
    },
};
use axum_extra::extract::cookie::Cookie;
use http_body_util::BodyExt;
use serde_json::Value;
use tower::ServiceExt;
use watch_club::{
    ApiContext, AppsSentry,
    db::Pool,
    domain::{accounts::CurrentUser, contents::MetadataProviders},
};

use super::{PASSWORD, encryption_key, http_client, unreachable_metadata_providers};

/// A browser or app calling the API. Like a browser, it keeps the cookies the API sets; like an
/// app, it can send a session token instead. A clone sends the same cookies and token, as if
/// someone copied them.
#[derive(Clone)]
pub struct Client {
    router: Router,
    cookies: BTreeMap<String, String>,
    headers: HeaderMap,
}

/// Returns the context of an app with the default settings, whose calls to the Metadata Providers
/// fail, and which encrypts with the tests' `ENCRYPTION_KEY`.
fn default_context(db: &Pool) -> ApiContext {
    ApiContext {
        db: db.clone(),
        instance_name: "WatchClub".into(),
        apps_sentry: AppsSentry {
            web_dsn: None,
            mobile_dsn: None,
            environment: "production".into(),
        },
        metadata_providers: unreachable_metadata_providers(),
        encryption_key: encryption_key(),
        http_client: http_client(),
    }
}

/// The API's answer to a request.
#[derive(Debug)]
pub struct Response {
    pub status: StatusCode,
    pub headers: HeaderMap,
    /// The JSON body, or `Null` when there's none
    pub body: Value,
}

impl Client {
    /// Calls an app whose calls to the Metadata Providers fail, as nothing answers them.
    pub fn new(db: &Pool) -> Self {
        Self::with_context(default_context(db))
    }

    /// Calls an app that calls these Metadata Providers, such as a `FakeTmdb`'s.
    pub fn with_metadata_providers(db: &Pool, metadata_providers: MetadataProviders) -> Self {
        Self::with_context(ApiContext {
            metadata_providers,
            ..default_context(db)
        })
    }

    /// Calls an app whose host named the Instance.
    pub fn with_instance_name(db: &Pool, instance_name: &str) -> Self {
        Self::with_context(ApiContext {
            instance_name: instance_name.into(),
            ..default_context(db)
        })
    }

    /// Calls an app whose host set these Sentry settings for the apps.
    pub fn with_apps_sentry(db: &Pool, apps_sentry: AppsSentry) -> Self {
        Self::with_context(ApiContext {
            apps_sentry,
            ..default_context(db)
        })
    }

    fn with_context(context: ApiContext) -> Self {
        Self {
            router: watch_club::router(context),
            cookies: BTreeMap::new(),
            headers: HeaderMap::new(),
        }
    }

    /// Sends this header with every request, as a reverse proxy in front of the server would.
    pub fn set_header(&mut self, name: &'static str, value: &'static str) {
        self.headers.insert(name, HeaderValue::from_static(value));
    }

    pub async fn get(&mut self, uri: &str) -> Response {
        self.send(Method::GET, uri, None).await
    }

    pub async fn post(&mut self, uri: &str, body: Value) -> Response {
        self.send(Method::POST, uri, Some(body)).await
    }

    pub async fn post_without_body(&mut self, uri: &str) -> Response {
        self.send(Method::POST, uri, None).await
    }

    pub async fn put(&mut self, uri: &str, body: Value) -> Response {
        self.send(Method::PUT, uri, Some(body)).await
    }

    pub async fn patch(&mut self, uri: &str, body: Value) -> Response {
        self.send(Method::PATCH, uri, Some(body)).await
    }

    pub async fn delete(&mut self, uri: &str) -> Response {
        self.send(Method::DELETE, uri, None).await
    }

    /// Signs the User in with `PASSWORD`, as the web app does.
    pub async fn sign_in(&mut self, user: &CurrentUser) {
        let credentials = serde_json::json!({ "username": user.username, "password": PASSWORD });
        let response = self.post("/api/auth/login", credentials).await;
        assert_eq!(response.status, StatusCode::OK, "{response:?}");
    }

    /// Signs the User in with `PASSWORD`, as the mobile apps do, and sends the token from then on.
    pub async fn sign_in_app(&mut self, user: &CurrentUser) {
        let credentials = serde_json::json!({ "username": user.username, "password": PASSWORD });
        let response = self.post("/api/auth/login/token", credentials).await;
        assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
        let token = response.body["token"].as_str().unwrap();
        let authorization = HeaderValue::from_str(&format!("Bearer {token}")).unwrap();
        self.headers.insert(AUTHORIZATION, authorization);
    }

    async fn send(&mut self, method: Method, uri: &str, body: Option<Value>) -> Response {
        let mut request = Request::builder().method(method).uri(uri);
        for (name, value) in &self.headers {
            request = request.header(name, value);
        }
        if !self.cookies.is_empty() {
            let cookies: Vec<_> = self
                .cookies
                .iter()
                .map(|(name, value)| format!("{name}={value}"))
                .collect();
            request = request.header(COOKIE, cookies.join("; "));
        }
        let body = match body {
            Some(json) => {
                request = request.header(CONTENT_TYPE, "application/json");
                Body::from(json.to_string())
            }
            None => Body::empty(),
        };

        let response = self
            .router
            .clone()
            .oneshot(request.body(body).unwrap())
            .await
            .unwrap();

        for header in response.headers().get_all(SET_COOKIE) {
            let cookie = Cookie::parse(header.to_str().unwrap()).unwrap();
            // The API removes a cookie by setting it again with no time left
            if cookie.max_age() == Some(time::Duration::ZERO) {
                self.cookies.remove(cookie.name());
            } else {
                self.cookies
                    .insert(cookie.name().to_owned(), cookie.value().to_owned());
            }
        }
        let status = response.status();
        let headers = response.headers().clone();
        let bytes = response.into_body().collect().await.unwrap().to_bytes();
        let body = if bytes.is_empty() {
            Value::Null
        } else {
            serde_json::from_slice(&bytes)
                .unwrap_or_else(|_| Value::String(String::from_utf8_lossy(&bytes).into_owned()))
        };
        Response {
            status,
            headers,
            body,
        }
    }
}
