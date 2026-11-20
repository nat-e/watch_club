//! The errors any API request can fail with, the body that every error response shares, and the
//! failure a caught panic stands for, which the API and the jobs report.

use std::{any::Any, fmt::Display, sync::Arc};

use anyhow::anyhow;
use axum::{
    Json,
    extract::{
        Request,
        rejection::{JsonRejection, PathRejection, QueryRejection},
    },
    http::{HeaderValue, StatusCode, header::WWW_AUTHENTICATE},
    middleware::Next,
    response::{IntoResponse, Response},
};
use serde::Serialize;
use serde_json::json;
use tracing::Level;
use utoipa::ToSchema;

/// The failures any endpoint can send, named after their HTTP status.
#[derive(Debug, thiserror::Error)]
pub(crate) enum ApiError {
    /// A body, path or query string that isn't what the endpoint takes, with why
    #[error("{0}")]
    InvalidRequest(String),
    #[error("not signed in")]
    Unauthorized,
    #[error("only the Instance Administrator can do this")]
    Forbidden,
    /// A failure the request can only report, such as the database being down
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// The kind of an `ApiError`, which sets its status and code. The OpenAPI document reads them
/// here, as it has no `ApiError` to ask.
#[derive(Clone, Copy)]
pub(crate) enum ApiErrorKind {
    InvalidRequest,
    Unauthorized,
    Forbidden,
    Internal,
}

impl ApiErrorKind {
    pub(crate) fn status(self) -> StatusCode {
        match self {
            Self::InvalidRequest => StatusCode::BAD_REQUEST,
            Self::Unauthorized => StatusCode::UNAUTHORIZED,
            Self::Forbidden => StatusCode::FORBIDDEN,
            Self::Internal => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }

    pub(crate) fn code(self) -> &'static str {
        match self {
            Self::InvalidRequest => "invalid_request",
            Self::Unauthorized => "unauthorized",
            Self::Forbidden => "forbidden",
            Self::Internal => "internal_error",
        }
    }
}

impl From<JsonRejection> for ApiError {
    fn from(rejection: JsonRejection) -> Self {
        Self::InvalidRequest(rejection.body_text())
    }
}

impl From<PathRejection> for ApiError {
    fn from(rejection: PathRejection) -> Self {
        Self::InvalidRequest(rejection.body_text())
    }
}

impl From<QueryRejection> for ApiError {
    fn from(rejection: QueryRejection) -> Self {
        Self::InvalidRequest(rejection.body_text())
    }
}

impl ApiError {
    fn kind(&self) -> ApiErrorKind {
        match self {
            Self::InvalidRequest(_) => ApiErrorKind::InvalidRequest,
            Self::Unauthorized => ApiErrorKind::Unauthorized,
            Self::Forbidden => ApiErrorKind::Forbidden,
            Self::Internal(_) => ApiErrorKind::Internal,
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let kind = self.kind();
        let message = match &self {
            Self::InvalidRequest(_) | Self::Unauthorized | Self::Forbidden => self.to_string(),
            // The cause stays in the logs
            Self::Internal(_) => "internal error".to_owned(),
        };
        let body = ErrorBody {
            error: json!({ "code": kind.code() }),
            message,
        };
        let mut response = (kind.status(), Json(body)).into_response();
        match self {
            Self::InvalidRequest(_) | Self::Forbidden => {}
            Self::Unauthorized => {
                let challenge = HeaderValue::from_static("Bearer");
                response.headers_mut().insert(WWW_AUTHENTICATE, challenge);
            }
            // For `log_internal_errors` to log
            Self::Internal(error) => {
                response.extensions_mut().insert(Arc::new(error));
            }
        }
        response
    }
}

/// The body of every error response: the error's `code` and details, and a message.
#[derive(Serialize, ToSchema)]
pub(crate) struct ErrorBody<E> {
    #[serde(flatten)]
    error: E,
    /// The failure in English, for developers rather than users
    message: String,
}

/// Returns an error response with the error's code and details, and its `Display` text.
pub(crate) fn response(status: StatusCode, error: &(impl Serialize + Display)) -> Response {
    let message = error.to_string();
    (status, Json(ErrorBody { error, message })).into_response()
}

/// Logs the cause of each 500 that `ApiError` sends. Inside `observability::instrument`, the log
/// shows the request's method and path.
pub(crate) async fn log_internal_errors(request: Request, next: Next) -> Response {
    let response = next.run(request).await;
    if let Some(error) = response.extensions().get::<Arc<anyhow::Error>>() {
        tracing::event!(
            name: "api.request.failed",
            Level::ERROR,
            exception.message = %format_args!("{error:#}"),
            "request failed",
        );
    }
    response
}

/// Answers a request whose handler panicked as any internal error: with a 500, which
/// `log_internal_errors` logs with the panic's message.
#[expect(
    clippy::needless_pass_by_value,
    reason = "`CatchPanicLayer` hands the panic over by value"
)]
pub(crate) fn panic_response(panic: Box<dyn Any + Send>) -> Response {
    ApiError::Internal(from_panic(&*panic)).into_response()
}

/// Returns the failure a caught panic stands for, with the panic's message when it has one, which
/// is a `&str` or a `String`.
pub(crate) fn from_panic(panic: &(dyn Any + Send)) -> anyhow::Error {
    let message = panic
        .downcast_ref::<&str>()
        .copied()
        .or_else(|| panic.downcast_ref::<String>().map(String::as_str))
        .unwrap_or("no message");
    anyhow!("panicked: {message}")
}

#[cfg(test)]
mod tests {
    use axum::{Router, body::Body, routing::get};
    use http_body_util::BodyExt;
    use serde_json::Value;
    use tower::ServiceExt;
    use tower_http::catch_panic::CatchPanicLayer;

    use super::*;

    #[tokio::test]
    async fn answers_a_panicking_handler_with_an_internal_error() {
        async fn panics() -> StatusCode {
            panic!("the handler broke")
        }
        let app = Router::new()
            .route("/", get(panics))
            .layer(CatchPanicLayer::custom(panic_response));

        let response = app
            .oneshot(Request::get("/").body(Body::empty()).unwrap())
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
        let error = response.extensions().get::<Arc<anyhow::Error>>().unwrap();
        assert_eq!(error.to_string(), "panicked: the handler broke");
        let body = response.into_body().collect().await.unwrap().to_bytes();
        let body: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(
            body,
            json!({ "code": "internal_error", "message": "internal error" })
        );
    }
}
