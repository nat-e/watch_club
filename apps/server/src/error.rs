//! The errors any API request can fail with, and the body that every error response shares.

use std::{any::Any, fmt::Display, sync::Arc};

use axum::{
    Json,
    extract::{Request, rejection::JsonRejection},
    http::{HeaderValue, StatusCode, header::WWW_AUTHENTICATE},
    middleware::Next,
    response::{IntoResponse, Response},
};
use serde::Serialize;
use serde_json::json;
use tracing::Level;
use utoipa::ToSchema;

use crate::domain::InternalError;

/// The failures any endpoint can send, named after their HTTP status.
#[derive(Debug, thiserror::Error)]
pub(crate) enum ApiError {
    #[error(transparent)]
    InvalidRequest(#[from] JsonRejection),
    #[error("not signed in")]
    Unauthorized,
    #[error(transparent)]
    Internal(#[from] InternalError),
}

/// The kind of an `ApiError`, which sets its status and code. The OpenAPI document reads them
/// here, as it has no `ApiError` to ask.
#[derive(Clone, Copy)]
pub(crate) enum ApiErrorKind {
    InvalidRequest,
    Unauthorized,
    Internal,
}

impl ApiErrorKind {
    pub(crate) fn status(self) -> StatusCode {
        match self {
            Self::InvalidRequest => StatusCode::BAD_REQUEST,
            Self::Unauthorized => StatusCode::UNAUTHORIZED,
            Self::Internal => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }

    pub(crate) fn code(self) -> &'static str {
        match self {
            Self::InvalidRequest => "invalid_request",
            Self::Unauthorized => "unauthorized",
            Self::Internal => "internal_error",
        }
    }
}

impl ApiError {
    fn kind(&self) -> ApiErrorKind {
        match self {
            Self::InvalidRequest(_) => ApiErrorKind::InvalidRequest,
            Self::Unauthorized => ApiErrorKind::Unauthorized,
            Self::Internal(_) => ApiErrorKind::Internal,
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let kind = self.kind();
        let message = match &self {
            Self::InvalidRequest(rejection) => rejection.body_text(),
            Self::Unauthorized => self.to_string(),
            // The cause stays in the logs
            Self::Internal(_) => "internal error".to_owned(),
        };
        let body = ErrorBody {
            error: json!({ "code": kind.code() }),
            message,
        };
        let mut response = (kind.status(), Json(body)).into_response();
        match self {
            Self::InvalidRequest(_) => {}
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
    if let Some(error) = response.extensions().get::<Arc<InternalError>>() {
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
    ApiError::Internal(InternalError::from_panic(&*panic)).into_response()
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
        let error = response.extensions().get::<Arc<InternalError>>().unwrap();
        assert_eq!(error.to_string(), "panicked: the handler broke");
        let body = response.into_body().collect().await.unwrap().to_bytes();
        let body: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(
            body,
            json!({ "code": "internal_error", "message": "internal error" })
        );
    }
}
