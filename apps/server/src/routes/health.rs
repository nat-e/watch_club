//! The health check, which Docker and uptime monitors call to know whether the server works.

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::Serialize;
use sqlx::{Connection, PgPool};
use utoipa::ToSchema;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    AppState,
    error::{self, ErrorBody},
};

pub(super) fn routes() -> OpenApiRouter<AppState> {
    OpenApiRouter::new().routes(routes!(check_health))
}

/// Checks that the server works: that it reaches its database.
#[utoipa::path(
    get,
    path = "/health",
    responses(
        (status = NO_CONTENT, description = "The server works"),
        (status = SERVICE_UNAVAILABLE, body = ErrorBody<HealthError>, description = "The server can't reach its database"),
    ),
)]
async fn check_health(State(db): State<PgPool>) -> Result<StatusCode, HealthError> {
    let result = match db.acquire().await {
        Ok(mut connection) => connection.ping().await,
        Err(error) => Err(error),
    };
    if let Err(error) = result {
        tracing::warn!("the health check can't reach the database: {error}");
        return Err(HealthError::DatabaseUnreachable);
    }
    Ok(StatusCode::NO_CONTENT)
}

/// The reason the server doesn't work.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum HealthError {
    #[error("the server can't reach its database")]
    DatabaseUnreachable,
}

impl IntoResponse for HealthError {
    fn into_response(self) -> Response {
        error::response(StatusCode::SERVICE_UNAVAILABLE, &self)
    }
}
