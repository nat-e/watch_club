//! The app's routes: the JSON API under `/api`, which the web and mobile apps call, and the web app
//! on every other path.

mod auth;
mod health;
mod instance;
mod me;

use axum::{
    extract::FromRequest,
    http::StatusCode,
    middleware,
    response::{IntoResponse, Response},
    routing::{any, get},
};
use serde::Serialize;
use tower_http::catch_panic::CatchPanicLayer;
use utoipa_axum::router::OpenApiRouter;

use crate::{
    AppState,
    error::{self, ApiError},
    observability, web,
};

/// Returns the app's routes, with the descriptions of the API's endpoints.
pub(crate) fn routes() -> OpenApiRouter<AppState> {
    let api = OpenApiRouter::new()
        .merge(instance::routes())
        .merge(auth::routes())
        .merge(me::routes())
        // Unknown API paths aren't found, rather than showing the web app
        .fallback(StatusCode::NOT_FOUND);
    let app = OpenApiRouter::new()
        .nest("/api", api)
        // The fallback misses this path: axum nests it at `/api` and `/api/{*rest}`, and the
        // wildcard doesn't match an empty rest
        .route("/api/", any(StatusCode::NOT_FOUND))
        .fallback_service(get(web::serve))
        // Answers a panicking handler with a 500, which the layers around it log and count as such.
        // The server goes on, an exception to M-PANIC-CONTINUATION: handlers share no state that a
        // panic could leave half-changed, and a restart would leave hosts without a restart policy
        // down
        .layer(CatchPanicLayer::custom(error::panic_response))
        // Inside `instrument`'s request span, so the log shows the request's method and path
        .layer(middleware::from_fn(error::log_internal_errors));
    observability::instrument(app)
        // After `instrument`, which leaves it out: Docker calls it every 30 seconds, and its traces
        // would bury the others
        .merge(OpenApiRouter::new().nest("/api", health::routes()))
}

/// Like axum's `Json`, but a body that isn't the JSON the endpoint takes fails with a 400. That
/// leaves 422 to mean that the request was well formed, but its values break a rule.
#[derive(FromRequest)]
#[from_request(via(axum::Json), rejection(ApiError))]
struct Json<T>(T);

impl<T: Serialize> IntoResponse for Json<T> {
    fn into_response(self) -> Response {
        axum::Json(self.0).into_response()
    }
}
