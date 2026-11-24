//! Media Imports, which the Instance Administrator starts and looks through in each Source's
//! history.

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    ApiContext,
    auth::InstanceAdministrator,
    db::Pool,
    domain::{
        media_imports::{self, FilesToImport, MediaImport, StartMediaImportError},
        sources::SourceId,
    },
    error::{self, ApiError, ErrorBody},
    routes::{Json, Path},
};

/// Returns the endpoints of Media Imports, which only the Instance Administrator calls.
pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new().routes(routes!(list_media_imports, start_media_import))
}

/// Returns the Source's imports, the latest first. A Source that doesn't exist has none.
#[utoipa::path(
    get,
    path = "/sources/{id}/media-imports",
    params(("id" = SourceId, Path, description = "The Source's ID")),
    responses((status = OK, body = Vec<MediaImport>)),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn list_media_imports(
    State(db): State<Pool>,
    _: InstanceAdministrator,
    Path(id): Path<SourceId>,
) -> Result<Json<Vec<MediaImport>>, ApiError> {
    let media_imports = media_imports::list(&db, id).await?;
    Ok(Json(media_imports))
}

/// Starts an import of the Source's files, which runs in the background.
#[utoipa::path(
    post,
    path = "/sources/{id}/media-imports",
    params(("id" = SourceId, Path, description = "The Source's ID")),
    request_body = StartMediaImportRequest,
    responses(
        (status = ACCEPTED, body = MediaImport),
        (status = NOT_FOUND, body = ErrorBody<StartMediaImportRequestError>, description = "There's no such Source"),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<StartMediaImportRequestError>, description = "The Source's type doesn't import yet"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn start_media_import(
    State(db): State<Pool>,
    _: InstanceAdministrator,
    Path(id): Path<SourceId>,
    Json(request): Json<StartMediaImportRequest>,
) -> Result<(StatusCode, Json<MediaImport>), StartMediaImportRequestError> {
    let media_import = media_imports::start(&db, id, request.files_to_import).await?;
    Ok((StatusCode::ACCEPTED, Json(media_import)))
}

/// The files of its Source an import handles.
#[derive(Deserialize, ToSchema)]
struct StartMediaImportRequest {
    files_to_import: FilesToImport,
}

/// The failures of a request to start an import.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum StartMediaImportRequestError {
    #[error("no such Source")]
    NotFound,
    /// Only Radarr Sources import yet
    #[error("the Source's type doesn't import yet")]
    UnsupportedSourceType,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
}

impl From<StartMediaImportError> for StartMediaImportRequestError {
    fn from(error: StartMediaImportError) -> Self {
        match error {
            StartMediaImportError::NotFound => Self::NotFound,
            StartMediaImportError::UnsupportedSourceType => Self::UnsupportedSourceType,
            StartMediaImportError::Internal(error) => Self::Internal(error),
        }
    }
}

impl IntoResponse for StartMediaImportRequestError {
    fn into_response(self) -> Response {
        let status = match self {
            Self::NotFound => StatusCode::NOT_FOUND,
            Self::UnsupportedSourceType => StatusCode::UNPROCESSABLE_ENTITY,
            Self::Internal(error) => return ApiError::from(error).into_response(),
        };
        error::response(status, &self)
    }
}
