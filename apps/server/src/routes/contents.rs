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
        contents::{self, Content, ContentId, ContentType, LookUpError, MetadataProviders},
    },
    error::{self, ApiError, ErrorBody},
    routes::{Json, Path},
};

pub(super) fn routes() -> OpenApiRouter<AppState> {
    OpenApiRouter::new().routes(routes!(get_content))
}

/// Returns the Content, with its title in the signed-in User's language.
#[utoipa::path(
    get,
    path = "/contents/{content_type}/{external_id}",
    params(
        ("content_type" = ContentType, Path, description = "The Content's type"),
        ("external_id" = String, Path, description = "The Content's ID at the Metadata Provider of its type, such as its TMDB ID"),
    ),
    responses(
        (status = OK, body = Content),
        (status = NOT_FOUND, body = ErrorBody<GetContentRequestError>, description = "There's no such Content"),
    ),
    security(("session_cookie" = []), ("session_token" = [])),
)]
async fn get_content(
    State(providers): State<MetadataProviders>,
    current_user: CurrentUser,
    Path((content_type, external_id)): Path<(ContentType, String)>,
) -> Result<Json<Content>, GetContentRequestError> {
    // An ID that can't be one is as unknown as one the Metadata Provider doesn't have
    let id =
        ContentId::parse(content_type, &external_id).ok_or(GetContentRequestError::NotFound)?;
    let content = contents::look_up(&providers, id, current_user.preferences.locale).await?;
    Ok(Json(content))
}

/// The failures of a request for a Content.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum GetContentRequestError {
    #[error("no such Content")]
    NotFound,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl From<LookUpError> for GetContentRequestError {
    fn from(error: LookUpError) -> Self {
        match error {
            LookUpError::NotFound => Self::NotFound,
            LookUpError::Internal(error) => Self::Internal(error.into()),
        }
    }
}

impl IntoResponse for GetContentRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::NotFound => error::response(StatusCode::NOT_FOUND, &self),
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}
