//! Contents, with how the API sends them.

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::Serialize;
use utoipa::ToSchema;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    AppState,
    domain::{
        InternalError,
        accounts::CurrentUser,
        contents::{self, Content, ContentId, ContentType, LookUpError},
    },
    error::{self, ApiError, ErrorBody},
    integrations::tmdb,
    routes::{Json, Path},
};

pub(super) fn routes() -> OpenApiRouter<AppState> {
    OpenApiRouter::new().routes(routes!(get_content))
}

/// Returns the Content, with its title in the signed-in User's language.
#[utoipa::path(
    get,
    path = "/contents/{content_type}/{tmdb_id}",
    params(
        ("content_type" = ContentType, Path, description = "The Content's type"),
        ("tmdb_id" = u32, Path, description = "The Content's TMDB ID"),
    ),
    responses(
        (status = OK, body = Content),
        (status = NOT_FOUND, body = ErrorBody<GetContentError>, description = "TMDB has no such Content"),
    ),
    security(("session_cookie" = []), ("session_token" = [])),
)]
async fn get_content(
    State(tmdb): State<tmdb::Client>,
    current_user: CurrentUser,
    Path((content_type, tmdb_id)): Path<(ContentType, u32)>,
) -> Result<Json<Content>, GetContentError> {
    let id = ContentId {
        content_type,
        tmdb_id,
    };
    let content = contents::look_up(&tmdb, id, current_user.preferences.locale).await?;
    Ok(Json(content))
}

/// The failures of a request for a Content.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum GetContentError {
    #[error("TMDB has no such Content")]
    NotFound,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl From<LookUpError> for GetContentError {
    fn from(error: LookUpError) -> Self {
        match error {
            LookUpError::NotFound => Self::NotFound,
            LookUpError::Internal(error) => Self::Internal(error.into()),
        }
    }
}

impl IntoResponse for GetContentError {
    fn into_response(self) -> Response {
        match self {
            Self::NotFound => error::response(StatusCode::NOT_FOUND, &self),
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}
