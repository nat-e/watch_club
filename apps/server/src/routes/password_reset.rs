//! Password Reset Links: a User who forgot their password opens one and chooses a new password.

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use secrecy::SecretString;
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    ApiContext,
    db::Pool,
    domain::{
        InternalError,
        accounts::{self, Password, PasswordError, ResetPasswordError},
    },
    error::{self, ApiError, ErrorBody},
    routes::{Json, Query},
};

pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new().routes(routes!(check_password_reset_link, reset_password))
}

/// Returns whose password a Password Reset Link resets, for the page that opens it.
#[utoipa::path(
    get,
    path = "/password-reset",
    params(PasswordResetTokenParams),
    responses((status = OK, body = PasswordResetLinkCheck)),
)]
async fn check_password_reset_link(
    State(db): State<Pool>,
    Query(params): Query<PasswordResetTokenParams>,
) -> Result<Json<PasswordResetLinkCheck>, ApiError> {
    let username = accounts::password_reset_username(&db, &params.token).await?;
    Ok(Json(PasswordResetLinkCheck { username }))
}

/// The token of a Password Reset Link, in the query string, where the logs and traces hide it.
#[derive(Deserialize, IntoParams)]
#[into_params(parameter_in = Query)]
struct PasswordResetTokenParams {
    /// The token in the Password Reset Link
    token: String,
}

/// Whose password a Password Reset Link resets.
#[derive(Serialize, ToSchema)]
struct PasswordResetLinkCheck {
    /// The User's username, or null when the link no longer works: it expired, was used or
    /// replaced, or never existed
    #[schema(required = true)]
    username: Option<String>,
}

/// Sets the password of the User whose Password Reset Link this is, and signs them out on every
/// device: they then sign in with the new password. The link stops working.
#[utoipa::path(
    post,
    path = "/password-reset",
    request_body = ResetPasswordRequest,
    responses(
        (status = NO_CONTENT, description = "Reset"),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<ResetPasswordRequestError>, description = "The link no longer works, or the password breaks the rules"),
    ),
)]
async fn reset_password(
    State(db): State<Pool>,
    Json(request): Json<ResetPasswordRequest>,
) -> Result<StatusCode, ResetPasswordRequestError> {
    let password = Password::parse(request.password)?;
    accounts::reset_password(&db, &request.token, password).await?;
    Ok(StatusCode::NO_CONTENT)
}

/// A new password, and the token of the Password Reset Link that lets the User choose it.
#[derive(Deserialize, ToSchema)]
#[schema(as = PasswordReset)]
struct ResetPasswordRequest {
    /// The token in the Password Reset Link
    token: String,
    #[schema(value_type = String)]
    password: SecretString,
}

/// The failures of a request to reset a password.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum ResetPasswordRequestError {
    #[error(transparent)]
    InvalidPassword {
        #[from]
        reason: PasswordError,
    },
    /// The Password Reset Link expired, was used or replaced, or never existed
    #[error("the Password Reset Link no longer works")]
    LinkNoLongerWorks,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl From<ResetPasswordError> for ResetPasswordRequestError {
    fn from(error: ResetPasswordError) -> Self {
        match error {
            ResetPasswordError::LinkNoLongerWorks => Self::LinkNoLongerWorks,
            ResetPasswordError::Internal(error) => Self::Internal(error.into()),
        }
    }
}

impl IntoResponse for ResetPasswordRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::InvalidPassword { .. } | Self::LinkNoLongerWorks => {
                error::response(StatusCode::UNPROCESSABLE_ENTITY, &self)
            }
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}
