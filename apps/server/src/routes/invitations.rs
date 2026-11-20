//! Invitations: the Instance Administrator manages them, and new people redeem them to create their
//! account.

use std::num::NonZeroU32;

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use axum_extra::extract::CookieJar;
use secrecy::SecretString;
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    ApiContext,
    auth::{InstanceAdministrator, SessionCookie},
    db::Pool,
    domain::accounts::{
        self, DeleteInvitationError, Invitation, InvitationId, Locale, Password,
        RedeemInvitationError, UpdateInvitationError, Username,
    },
    error::{self, ApiError, ErrorBody},
    routes::{
        Json, Path, Query,
        me::CurrentUserResponse,
        users::{ApiPasswordError, ApiUsernameError},
    },
};

pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new()
        .routes(routes!(list_invitations, create_invitation))
        .routes(routes!(update_invitation, delete_invitation))
        .routes(routes!(check_invitation))
        .routes(routes!(redeem_invitation))
}

/// Returns the Invitations that can still be redeemed, the oldest first.
#[utoipa::path(
    get,
    path = "/invitations",
    responses((status = OK, body = Vec<Invitation>)),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn list_invitations(
    State(db): State<Pool>,
    _: InstanceAdministrator,
) -> Result<Json<Vec<Invitation>>, ApiError> {
    Ok(Json(accounts::list_redeemable_invitations(&db).await?))
}

/// Creates an Invitation with a random code, which works for 7 days.
#[utoipa::path(
    post,
    path = "/invitations",
    request_body = InvitationRequest,
    responses((status = CREATED, body = Invitation)),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn create_invitation(
    State(db): State<Pool>,
    _: InstanceAdministrator,
    Json(request): Json<InvitationRequest>,
) -> Result<(StatusCode, Json<Invitation>), ApiError> {
    let invitation = accounts::create_invitation(&db, request.max_uses).await?;
    Ok((StatusCode::CREATED, Json(invitation)))
}

/// Changes the Invitation's Max Uses, and returns the Invitation.
#[utoipa::path(
    patch,
    path = "/invitations/{invitation_id}",
    params(("invitation_id" = InvitationId, Path, description = "The Invitation's ID")),
    request_body = InvitationRequest,
    responses(
        (status = OK, body = Invitation),
        (status = NOT_FOUND, body = ErrorBody<UpdateInvitationRequestError>, description = "There's no such Invitation"),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<UpdateInvitationRequestError>, description = "The Invitation has created more Users than the Max Uses already"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn update_invitation(
    State(db): State<Pool>,
    _: InstanceAdministrator,
    Path(invitation_id): Path<InvitationId>,
    Json(request): Json<InvitationRequest>,
) -> Result<Json<Invitation>, UpdateInvitationRequestError> {
    let invitation = accounts::update_invitation(&db, invitation_id, request.max_uses).await?;
    Ok(Json(invitation))
}

/// The settings the Instance Administrator chooses for an Invitation.
#[derive(Deserialize, ToSchema)]
#[schema(as = InvitationSettings)]
struct InvitationRequest {
    /// The most Users it can create, or null for no limit
    // Required even though it can be null, so that leaving it out doesn't remove the limit
    #[serde(deserialize_with = "Option::deserialize")]
    #[schema(value_type = Option<u32>, minimum = 1, required = true)]
    max_uses: Option<NonZeroU32>,
}

/// The failures of a request to change an Invitation.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum UpdateInvitationRequestError {
    #[error("no such Invitation")]
    InvitationNotFound,
    /// The Invitation has created more Users than the Max Uses already
    #[error("the Max Uses is lower than the Invitation's uses")]
    MaxUsesTooLow,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
}

impl From<UpdateInvitationError> for UpdateInvitationRequestError {
    fn from(error: UpdateInvitationError) -> Self {
        match error {
            UpdateInvitationError::InvitationNotFound => Self::InvitationNotFound,
            UpdateInvitationError::MaxUsesTooLow => Self::MaxUsesTooLow,
            UpdateInvitationError::Internal(error) => Self::Internal(error),
        }
    }
}

impl IntoResponse for UpdateInvitationRequestError {
    fn into_response(self) -> Response {
        let status = match self {
            Self::InvitationNotFound => StatusCode::NOT_FOUND,
            Self::MaxUsesTooLow => StatusCode::UNPROCESSABLE_ENTITY,
            Self::Internal(error) => return ApiError::from(error).into_response(),
        };
        error::response(status, &self)
    }
}

/// Deletes the Invitation, so that nobody can redeem it anymore. The Users it created stay.
#[utoipa::path(
    delete,
    path = "/invitations/{invitation_id}",
    params(("invitation_id" = InvitationId, Path, description = "The Invitation's ID")),
    responses(
        (status = NO_CONTENT, description = "Deleted"),
        (status = NOT_FOUND, body = ErrorBody<DeleteInvitationRequestError>, description = "There's no such Invitation"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn delete_invitation(
    State(db): State<Pool>,
    _: InstanceAdministrator,
    Path(invitation_id): Path<InvitationId>,
) -> Result<StatusCode, DeleteInvitationRequestError> {
    accounts::delete_invitation(&db, invitation_id).await?;
    Ok(StatusCode::NO_CONTENT)
}

/// The failures of a request to delete an Invitation.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum DeleteInvitationRequestError {
    #[error("no such Invitation")]
    InvitationNotFound,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
}

impl From<DeleteInvitationError> for DeleteInvitationRequestError {
    fn from(error: DeleteInvitationError) -> Self {
        match error {
            DeleteInvitationError::InvitationNotFound => Self::InvitationNotFound,
            DeleteInvitationError::Internal(error) => Self::Internal(error),
        }
    }
}

impl IntoResponse for DeleteInvitationRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::InvitationNotFound => error::response(StatusCode::NOT_FOUND, &self),
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}

/// Returns whether the code is an Invitation's that can still be redeemed, for the page that
/// redeems it.
#[utoipa::path(
    get,
    path = "/invitations/redeemable",
    params(InvitationCodeParams),
    responses((status = OK, body = InvitationCheck)),
)]
async fn check_invitation(
    State(db): State<Pool>,
    Query(params): Query<InvitationCodeParams>,
) -> Result<Json<InvitationCheck>, ApiError> {
    let redeemable = accounts::is_redeemable(&db, &params.code).await?;
    Ok(Json(InvitationCheck { redeemable }))
}

/// The code of an Invitation, in the query string, where the logs and traces hide it.
#[derive(Deserialize, IntoParams)]
#[into_params(parameter_in = Query)]
struct InvitationCodeParams {
    /// The code in the Invitation's link
    code: String,
}

/// Whether an Invitation can still be redeemed.
#[derive(Serialize, ToSchema)]
struct InvitationCheck {
    /// False when no Invitation has the code, or when it expired or created its Max Uses of Users
    redeemable: bool,
}

/// Creates a User with an Invitation, and signs the browser in as them. The Invitation counts one
/// more use.
#[utoipa::path(
    post,
    path = "/invitations/redeem",
    request_body = RedeemInvitationRequest,
    responses(
        (status = CREATED, body = CurrentUserResponse, description = "Created, and signed in with the session cookie"),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<RedeemInvitationRequestError>, description = "The Invitation can't be redeemed, or the username or password breaks the rules"),
    ),
)]
async fn redeem_invitation(
    State(db): State<Pool>,
    cookie: SessionCookie,
    Json(request): Json<RedeemInvitationRequest>,
) -> Result<(StatusCode, CookieJar, Json<CurrentUserResponse>), RedeemInvitationRequestError> {
    let RedeemInvitationRequest {
        code,
        username,
        password,
        locale,
    } = request;
    let username = Username::parse(&username).map_err(ApiUsernameError::from)?;
    let password = Password::parse(password).map_err(ApiPasswordError::from)?;
    let (user, token) = accounts::redeem_invitation(&db, &code, username, password, locale).await?;
    Ok((StatusCode::CREATED, cookie.set(&token), Json(user.into())))
}

/// A new person's account, and the code of the Invitation they create it with.
#[derive(Deserialize, ToSchema)]
#[schema(as = InvitationRedemption)]
struct RedeemInvitationRequest {
    /// The code in the Invitation's link
    code: String,
    username: String,
    #[schema(value_type = String)]
    password: SecretString,
    /// The Locale of the visitor's browser
    locale: Locale,
}

/// The failures of a request to redeem an Invitation.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum RedeemInvitationRequestError {
    #[error(transparent)]
    InvalidUsername {
        #[from]
        reason: ApiUsernameError,
    },
    #[error(transparent)]
    InvalidPassword {
        #[from]
        reason: ApiPasswordError,
    },
    #[error("another User has the username")]
    UsernameTaken,
    /// No Invitation has the code, or it expired or created its Max Uses of Users
    #[error("the Invitation can't be redeemed")]
    InvitationNotRedeemable,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
}

impl From<RedeemInvitationError> for RedeemInvitationRequestError {
    fn from(error: RedeemInvitationError) -> Self {
        match error {
            RedeemInvitationError::NotRedeemable => Self::InvitationNotRedeemable,
            RedeemInvitationError::UsernameTaken => Self::UsernameTaken,
            RedeemInvitationError::Internal(error) => Self::Internal(error),
        }
    }
}

impl IntoResponse for RedeemInvitationRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::InvalidUsername { .. }
            | Self::InvalidPassword { .. }
            | Self::UsernameTaken
            | Self::InvitationNotRedeemable => {
                error::response(StatusCode::UNPROCESSABLE_ENTITY, &self)
            }
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}
