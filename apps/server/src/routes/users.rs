//! The Users of the Instance: the list every User sees, and deleting them.

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
    auth::InstanceAdministrator,
    db::Pool,
    domain::{
        InternalError,
        accounts::{self, CurrentUser, DeleteUserError, User, UserId},
    },
    error::{self, ApiError, ErrorBody},
    routes::{Json, Path},
};

pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new()
        .routes(routes!(list_users))
        .routes(routes!(delete_user))
}

/// Returns every User, the first to join first.
#[utoipa::path(
    get,
    path = "/users",
    responses((status = OK, body = Vec<User>)),
    security(("session_cookie" = []), ("session_token" = [])),
)]
async fn list_users(State(db): State<Pool>, _: CurrentUser) -> Result<Json<Vec<User>>, ApiError> {
    Ok(Json(accounts::list_users(&db).await?))
}

/// Deletes the User, which signs them out on every device. Succeeds when there's no such User.
#[utoipa::path(
    delete,
    path = "/users/{user_id}",
    params(("user_id" = UserId, Path, description = "The User's ID")),
    responses(
        (status = NO_CONTENT, description = "Deleted, or there was no such User"),
        (status = CONFLICT, body = ErrorBody<DeleteUserRequestError>, description = "The Instance Administrator can't be deleted"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn delete_user(
    State(db): State<Pool>,
    _: InstanceAdministrator,
    Path(user): Path<UserId>,
) -> Result<StatusCode, DeleteUserRequestError> {
    accounts::delete_user(&db, user).await?;
    Ok(StatusCode::NO_CONTENT)
}

/// The failures of a request to delete a User.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum DeleteUserRequestError {
    #[error("the Instance Administrator can't be deleted")]
    IsInstanceAdministrator,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl From<DeleteUserError> for DeleteUserRequestError {
    fn from(error: DeleteUserError) -> Self {
        match error {
            DeleteUserError::InstanceAdministrator => Self::IsInstanceAdministrator,
            DeleteUserError::Internal(error) => Self::Internal(error.into()),
        }
    }
}

impl IntoResponse for DeleteUserRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::IsInstanceAdministrator => error::response(StatusCode::CONFLICT, &self),
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}
