//! The Users of the Instance, which the Instance Administrator lists and deletes, and whose Password
//! Reset Links they create.

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use secrecy::ExposeSecret;
use serde::Serialize;
use utoipa::ToSchema;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    ApiContext,
    auth::InstanceAdministrator,
    db::Pool,
    domain::{
        InternalError,
        accounts::{self, CreatePasswordResetLinkError, DeleteUserError, User, UserId},
    },
    error::{self, ApiError, ErrorBody},
    routes::{Json, Path},
};

pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new()
        .routes(routes!(list_users))
        .routes(routes!(delete_user))
        .routes(routes!(create_password_reset_link))
}

/// Returns every User, the first to join first.
#[utoipa::path(
    get,
    path = "/users",
    responses((status = OK, body = Vec<User>)),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn list_users(
    State(db): State<Pool>,
    _: InstanceAdministrator,
) -> Result<Json<Vec<User>>, ApiError> {
    Ok(Json(accounts::list_users(&db).await?))
}

/// Deletes the User, which signs them out on every device.
#[utoipa::path(
    delete,
    path = "/users/{user_id}",
    params(("user_id" = UserId, Path, description = "The User's ID")),
    responses(
        (status = NO_CONTENT, description = "Deleted"),
        (status = NOT_FOUND, body = ErrorBody<DeleteUserRequestError>, description = "There's no such User"),
        (status = CONFLICT, body = ErrorBody<DeleteUserRequestError>, description = "The Instance Administrator can't be deleted"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn delete_user(
    State(db): State<Pool>,
    _: InstanceAdministrator,
    Path(user_id): Path<UserId>,
) -> Result<StatusCode, DeleteUserRequestError> {
    accounts::delete_user(&db, user_id).await?;
    Ok(StatusCode::NO_CONTENT)
}

/// The failures of a request to delete a User.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum DeleteUserRequestError {
    #[error("no such User")]
    UserNotFound,
    #[error("the Instance Administrator can't be deleted")]
    CannotDeleteAdministrator,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl From<DeleteUserError> for DeleteUserRequestError {
    fn from(error: DeleteUserError) -> Self {
        match error {
            DeleteUserError::UserNotFound => Self::UserNotFound,
            DeleteUserError::CannotDeleteAdministrator => Self::CannotDeleteAdministrator,
            DeleteUserError::Internal(error) => Self::Internal(error.into()),
        }
    }
}

impl IntoResponse for DeleteUserRequestError {
    fn into_response(self) -> Response {
        let status = match self {
            Self::UserNotFound => StatusCode::NOT_FOUND,
            Self::CannotDeleteAdministrator => StatusCode::CONFLICT,
            Self::Internal(error) => return ApiError::from(error).into_response(),
        };
        error::response(status, &self)
    }
}

/// Creates a Password Reset Link for the User, which lets them choose a new password once, for 3
/// days. It replaces their last link, which stops working.
#[utoipa::path(
    post,
    path = "/users/{user_id}/password-reset-link",
    params(("user_id" = UserId, Path, description = "The User's ID")),
    responses(
        (status = CREATED, body = PasswordResetLink),
        (status = NOT_FOUND, body = ErrorBody<CreatePasswordResetLinkRequestError>, description = "There's no such User"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn create_password_reset_link(
    State(db): State<Pool>,
    _: InstanceAdministrator,
    Path(user_id): Path<UserId>,
) -> Result<(StatusCode, Json<PasswordResetLink>), CreatePasswordResetLinkRequestError> {
    let token = accounts::create_password_reset_link(&db, user_id).await?;
    let link = PasswordResetLink {
        token: token.expose_secret().to_owned(),
    };
    Ok((StatusCode::CREATED, Json(link)))
}

/// A link that lets a User choose a new password once, until it expires.
#[derive(Serialize, ToSchema)]
struct PasswordResetLink {
    /// The token in the link
    token: String,
}

/// The failures of a request to create a Password Reset Link.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum CreatePasswordResetLinkRequestError {
    #[error("no such User")]
    UserNotFound,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl From<CreatePasswordResetLinkError> for CreatePasswordResetLinkRequestError {
    fn from(error: CreatePasswordResetLinkError) -> Self {
        match error {
            CreatePasswordResetLinkError::UserNotFound => Self::UserNotFound,
            CreatePasswordResetLinkError::Internal(error) => Self::Internal(error.into()),
        }
    }
}

impl IntoResponse for CreatePasswordResetLinkRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::UserNotFound => error::response(StatusCode::NOT_FOUND, &self),
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}
