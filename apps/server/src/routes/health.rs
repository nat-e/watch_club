//! The health check, which Docker and uptime monitors call to know whether the server works.

use axum::{extract::State, http::StatusCode};
use sqlx::PgPool;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::AppState;

pub(super) fn routes() -> OpenApiRouter<AppState> {
    OpenApiRouter::new().routes(routes!(check_health))
}

/// Checks that the server reaches its database.
#[utoipa::path(
    get,
    path = "/health",
    responses(
        (status = OK, description = "It does"),
        (status = SERVICE_UNAVAILABLE, description = "It doesn't"),
    ),
)]
async fn check_health(State(db): State<PgPool>) -> StatusCode {
    match db.acquire().await {
        Ok(_) => StatusCode::OK,
        Err(_) => StatusCode::SERVICE_UNAVAILABLE,
    }
}
