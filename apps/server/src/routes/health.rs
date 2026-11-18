//! The health check, which Docker and uptime monitors call to know whether the server works.

use axum::{extract::State, http::StatusCode};
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{ApiContext, db::Pool};

pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new().routes(routes!(check_health))
}

/// Checks that the server reaches its database.
#[utoipa::path(
    get,
    path = "/health",
    responses(
        (status = OK, description = "The server works"),
        (status = SERVICE_UNAVAILABLE, description = "The server doesn't work"),
    ),
)]
async fn check_health(State(db): State<Pool>) -> StatusCode {
    match db.acquire().await {
        Ok(_) => StatusCode::OK,
        Err(_) => StatusCode::SERVICE_UNAVAILABLE,
    }
}
