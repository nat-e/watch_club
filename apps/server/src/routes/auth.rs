//! Signing in and out. The web app signs in with a session cookie, which its scripts can't read;
//! the mobile apps get a token to send in their `Authorization` header instead.

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use axum_extra::extract::CookieJar;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use utoipa::ToSchema;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    auth::SessionCookie,
    domain::{
        InternalError,
        accounts::{self, SessionToken, User},
    },
    error::{self, ApiError, ErrorBody},
    routes::Json,
};

pub(super) fn routes() -> OpenApiRouter<PgPool> {
    OpenApiRouter::new()
        .routes(routes!(login))
        .routes(routes!(login_token))
        .routes(routes!(logout))
}

/// Signs the browser in with a session cookie.
#[utoipa::path(
    post,
    path = "/auth/login",
    request_body = LoginRequest,
    responses(
        (status = OK, body = User, description = "Signed in with the session cookie"),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<LoginRequestError>, description = "Wrong username or password"),
    ),
)]
async fn login(
    State(db): State<PgPool>,
    cookie: SessionCookie,
    Json(credentials): Json<LoginRequest>,
) -> Result<(CookieJar, Json<User>), LoginRequestError> {
    let (user, token) = accounts::sign_in(&db, &credentials.username, credentials.password)
        .await?
        .ok_or(LoginRequestError::WrongCredentials)?;
    Ok((cookie.set(&token), Json(user)))
}

/// A username and password to sign in with.
#[derive(Deserialize, ToSchema)]
#[schema(as = Credentials)]
struct LoginRequest {
    username: String,
    password: String,
}

/// The failures of a request to sign in.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum LoginRequestError {
    #[error("wrong username or password")]
    WrongCredentials,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl IntoResponse for LoginRequestError {
    fn into_response(self) -> Response {
        let status = match self {
            Self::WrongCredentials => StatusCode::UNPROCESSABLE_ENTITY,
            Self::Internal(error) => return ApiError::from(error).into_response(),
        };
        error::response(status, &self)
    }
}

/// Signs a mobile app in, and returns the token it sends with every request.
#[utoipa::path(
    post,
    path = "/auth/login/token",
    request_body = LoginRequest,
    responses(
        (status = CREATED, body = LoginTokenResponse),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<LoginRequestError>, description = "Wrong username or password"),
    ),
)]
async fn login_token(
    State(db): State<PgPool>,
    Json(credentials): Json<LoginRequest>,
) -> Result<(StatusCode, Json<LoginTokenResponse>), LoginRequestError> {
    let (user, token) = accounts::sign_in(&db, &credentials.username, credentials.password)
        .await?
        .ok_or(LoginRequestError::WrongCredentials)?;
    let session = LoginTokenResponse {
        token: token.encode(),
        user,
    };
    Ok((StatusCode::CREATED, Json(session)))
}

/// The session token a mobile app signed in with, and its User.
#[derive(Serialize, ToSchema)]
#[schema(as = AppSession)]
struct LoginTokenResponse {
    /// The token to send as `Authorization: Bearer <token>`
    token: String,
    user: User,
}

/// Signs out the browser or app the request comes from. Succeeds when it's signed out already.
#[utoipa::path(
    post,
    path = "/auth/logout",
    responses((status = NO_CONTENT, description = "Signed out, and the session cookie removed")),
    security((), ("session_cookie" = []), ("session_token" = [])),
)]
async fn logout(
    State(db): State<PgPool>,
    token: Option<SessionToken>,
    cookie: SessionCookie,
) -> Result<(StatusCode, CookieJar), ApiError> {
    if let Some(token) = token {
        accounts::delete_session(&db, &token).await?;
    }
    Ok((StatusCode::NO_CONTENT, cookie.remove()))
}
