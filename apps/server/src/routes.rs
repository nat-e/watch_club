//! The app's routes: the JSON API under `/api`, which the web and mobile apps call, and the web app
//! on every other path.

mod auth;
mod contents;
mod health;
mod instance;
mod invitations;
mod me;
mod media_imports;
mod password_reset;
mod search;
mod sources;
mod users;

use axum::{
    extract::{FromRequest, FromRequestParts},
    middleware,
    response::{IntoResponse, Response},
    routing::{any, get},
};
use serde::Serialize;
use tower_http::catch_panic::CatchPanicLayer;
use utoipa_axum::router::OpenApiRouter;

use crate::{
    ApiContext,
    error::{self, ApiError},
    observability, web,
};

/// Returns the app's routes, with the descriptions of the API's endpoints.
pub(crate) fn routes() -> OpenApiRouter<ApiContext> {
    let api = OpenApiRouter::new()
        .merge(instance::routes())
        .merge(auth::routes())
        .merge(me::routes())
        .merge(users::routes())
        .merge(invitations::routes())
        .merge(password_reset::routes())
        .merge(search::routes())
        .merge(contents::routes())
        .merge(sources::routes())
        .merge(media_imports::routes())
        // Unknown API paths aren't found, rather than showing the web app
        .fallback(unknown_endpoint);
    let app = OpenApiRouter::new()
        .nest("/api", answer_method_not_allowed(api))
        // The fallback misses this path: axum nests it at `/api` and `/api/{*rest}`, and the
        // wildcard doesn't match an empty rest
        .route("/api/", any(unknown_endpoint))
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
        .merge(OpenApiRouter::new().nest("/api", answer_method_not_allowed(health::routes())))
}

/// Answers a request to a path no endpoint has.
async fn unknown_endpoint() -> ApiError {
    ApiError::UnknownEndpoint
}

/// Answers the requests whose method the endpoint at their path doesn't take with the API's 405,
/// to which axum adds the `Allow` header. Goes after the endpoints, as it only reaches those
/// already there.
fn answer_method_not_allowed(endpoints: OpenApiRouter<ApiContext>) -> OpenApiRouter<ApiContext> {
    // `OpenApiRouter` doesn't offer it, so it goes on its axum router
    let (router, openapi) = endpoints.split_for_parts();
    let router = router.method_not_allowed_fallback(async || ApiError::MethodNotAllowed);
    OpenApiRouter::with_openapi(openapi).merge(router.into())
}

/// Like axum's `Json`, but a body that isn't the JSON the endpoint takes fails with a 400. That
/// leaves 422 for every well-formed request that an endpoint refuses, such as one with a taken
/// username: its `code` says why.
#[derive(FromRequest)]
#[from_request(via(axum::Json), rejection(ApiError))]
struct Json<T>(T);

/// Like axum's `Path`, but a path that isn't what the endpoint takes fails with the API's 400.
#[derive(FromRequestParts)]
#[from_request(via(axum::extract::Path), rejection(ApiError))]
struct Path<T>(T);

/// Like axum's `Query`, but a query string that isn't what the endpoint takes fails with the API's
/// 400.
#[derive(FromRequestParts)]
#[from_request(via(axum::extract::Query), rejection(ApiError))]
struct Query<T>(T);

impl<T: Serialize> IntoResponse for Json<T> {
    fn into_response(self) -> Response {
        axum::Json(self.0).into_response()
    }
}
