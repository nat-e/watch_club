//! The Users of the Instance, which the Instance Administrator lists and deletes, and whose Password
//! Reset Links they create. Also how the API reports a username or password that breaks the rules.

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
    domain::accounts::users::{
        self, CreatePasswordResetLinkError, DeleteUserError, ParsePasswordError,
        ParseUsernameError, User, UserId,
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
    Ok(Json(users::list(&db).await?))
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
    users::delete(&db, user_id).await?;
    Ok(StatusCode::NO_CONTENT)
}

/// The failures of a request to delete a User.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum DeleteUserRequestError {
    #[error("no such User")]
    NotFound,
    #[error("the Instance Administrator can't be deleted")]
    CannotDeleteAdministrator,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
}

impl From<DeleteUserError> for DeleteUserRequestError {
    fn from(error: DeleteUserError) -> Self {
        match error {
            DeleteUserError::NotFound => Self::NotFound,
            DeleteUserError::IsInstanceAdministrator => Self::CannotDeleteAdministrator,
            DeleteUserError::Internal(error) => Self::Internal(error),
        }
    }
}

impl IntoResponse for DeleteUserRequestError {
    fn into_response(self) -> Response {
        let status = match self {
            Self::NotFound => StatusCode::NOT_FOUND,
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
    let token = users::create_password_reset_link(&db, user_id).await?;
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
    NotFound,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
}

impl From<CreatePasswordResetLinkError> for CreatePasswordResetLinkRequestError {
    fn from(error: CreatePasswordResetLinkError) -> Self {
        match error {
            CreatePasswordResetLinkError::NotFound => Self::NotFound,
            CreatePasswordResetLinkError::Internal(error) => Self::Internal(error),
        }
    }
}

impl IntoResponse for CreatePasswordResetLinkRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::NotFound => error::response(StatusCode::NOT_FOUND, &self),
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}

/// Potential errors when parsing Usernames
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
#[schema(as = UsernameProblem)]
pub(super) enum ApiUsernameError {
    #[error("the username is missing")]
    Missing,
    #[error("the username is shorter than {min} characters")]
    TooShort { min: usize },
    #[error("the username is longer than {max} characters")]
    TooLong { max: usize },
    /// Characters other than lowercase letters, digits and underscores
    #[error("the username has characters other than lowercase letters, digits and underscores")]
    InvalidCharacters,
}

impl From<ParseUsernameError> for ApiUsernameError {
    fn from(error: ParseUsernameError) -> Self {
        match error {
            ParseUsernameError::Missing => Self::Missing,
            ParseUsernameError::TooShort { min } => Self::TooShort { min },
            ParseUsernameError::TooLong { max } => Self::TooLong { max },
            ParseUsernameError::InvalidCharacters => Self::InvalidCharacters,
        }
    }
}

/// Potential errors when parsing Passwords
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
#[schema(as = PasswordProblem)]
pub(super) enum ApiPasswordError {
    #[error("the password is missing")]
    Missing,
    #[error("the password is shorter than {min} characters")]
    TooShort { min: usize },
}

impl From<ParsePasswordError> for ApiPasswordError {
    fn from(error: ParsePasswordError) -> Self {
        match error {
            ParsePasswordError::Missing => Self::Missing,
            ParsePasswordError::TooShort { min } => Self::TooShort { min },
        }
    }
}
