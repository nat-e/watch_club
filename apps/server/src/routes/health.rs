//! The health check, which Docker and uptime monitors call to know whether the server works.

use std::time::Duration;

use axum::{extract::State, http::StatusCode};
use tokio::time;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{ApiContext, db::Pool};

/// The longest the check waits for a connection: less than the 5 s Docker waits for an answer, so
/// that a server whose connections are all busy answers 503 rather than nothing
const CHECK_TIMEOUT: Duration = Duration::from_secs(3);

pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new().routes(routes!(check_health))
}

/// Checks that the server reaches its database within 3 s.
#[utoipa::path(
    get,
    path = "/health",
    responses(
        (status = OK, description = "The server works"),
        (status = SERVICE_UNAVAILABLE, description = "The server doesn't work"),
    ),
)]
async fn check_health(State(db): State<Pool>) -> StatusCode {
    match time::timeout(CHECK_TIMEOUT, db.acquire()).await {
        Ok(Ok(_)) => StatusCode::OK,
        Ok(Err(_)) | Err(_) => StatusCode::SERVICE_UNAVAILABLE,
    }
}
