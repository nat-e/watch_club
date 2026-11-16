//! The JSON API under `/api`, which the web and mobile apps call; `web` serves the other paths.

mod auth;
mod instance;
mod me;

use axum::{
    extract::FromRequest,
    response::{IntoResponse, Response},
};
use serde::Serialize;
use sqlx::PgPool;
use utoipa_axum::router::OpenApiRouter;

use crate::error::ApiError;

/// The path every API path starts with.
pub const PATH: &str = "/api";

/// Returns the routes of the API, with the descriptions of their endpoints.
pub(crate) fn routes() -> OpenApiRouter<PgPool> {
    let api = OpenApiRouter::new()
        .merge(instance::routes())
        .merge(auth::routes())
        .merge(me::routes());
    OpenApiRouter::new().nest(PATH, api)
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
