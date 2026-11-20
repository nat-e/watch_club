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
    ApiContext,
    db::Pool,
    domain::{
        accounts::CurrentUser,
        contents::{
            self, Content, ContentId, ContentType, ExternalContentId, LookUpContentError, Media,
            MetadataProviders,
        },
    },
    error::{self, ApiError, ErrorBody},
    routes::{Json, Path},
};

pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new()
        .routes(routes!(get_content_by_external_id))
        .routes(routes!(list_media_of_content))
}

/// Returns the Content, with its texts in the signed-in User's Locale. The first time someone opens
/// it, WatchClub saves it from its Metadata Provider first.
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
async fn get_content_by_external_id(
    State(db): State<Pool>,
    State(metadata_providers): State<MetadataProviders>,
    current_user: CurrentUser,
    Path((content_type, external_id)): Path<(ContentType, String)>,
) -> Result<Json<Content>, GetContentRequestError> {
    // An ID that can't be one is as unknown as one the Metadata Provider doesn't have
    let Some(external_content_id) = ExternalContentId::parse(content_type, &external_id) else {
        return Err(GetContentRequestError::NotFound);
    };

    let locale = current_user.preferences.locale;
    let content =
        contents::get_by_external_id(&db, &metadata_providers, external_content_id, locale).await?;
    Ok(Json(content))
}

/// Returns the Content's Media in order, such as a TV Show's Episodes by season and episode, with
/// their texts in the signed-in User's Locale. A Content that isn't saved has none.
#[utoipa::path(
    get,
    path = "/contents/{content_id}/media",
    params(("content_id" = ContentId, Path, description = "The Content's ID in WatchClub")),
    responses((status = OK, body = Vec<Media>)),
    security(("session_cookie" = []), ("session_token" = [])),
)]
async fn list_media_of_content(
    State(db): State<Pool>,
    current_user: CurrentUser,
    Path(content_id): Path<ContentId>,
) -> Result<Json<Vec<Media>>, ApiError> {
    let locale = current_user.preferences.locale;
    let media = contents::list_media(&db, content_id, locale).await?;
    Ok(Json(media))
}

/// The failures of a request for a Content.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum GetContentRequestError {
    #[error("no such Content")]
    NotFound,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
}

impl From<LookUpContentError> for GetContentRequestError {
    fn from(error: LookUpContentError) -> Self {
        match error {
            LookUpContentError::NotFound => Self::NotFound,
            LookUpContentError::Internal(error) => Self::Internal(error),
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
