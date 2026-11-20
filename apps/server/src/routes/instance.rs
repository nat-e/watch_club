//! The WatchClub instance: its name, whether it's set up yet, and Setup, where its first visitor creates
//! the Instance Administrator.

use std::sync::Arc;

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use axum_extra::extract::CookieJar;
use secrecy::SecretString;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    ApiContext,
    auth::SessionCookie,
    db::Pool,
    domain::accounts::{
        self, CreateInstanceAdministratorError, Locale, Password, PasswordError, Username,
        UsernameError,
    },
    error::{self, ApiError, ErrorBody},
    routes::{Json, me::CurrentUserResponse},
};

pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new()
        .routes(routes!(get_instance))
        .routes(routes!(create_instance_administrator))
}

/// Returns the information apps need about the WatchClub instance, which they read before signing
/// in too.
#[utoipa::path(get, path = "/instance", responses((status = OK, body = GetInstanceResponse)))]
async fn get_instance(
    State(context): State<ApiContext>,
) -> Result<Json<GetInstanceResponse>, ApiError> {
    let needs_setup = !accounts::has_instance_administrator(&context.db).await?;
    Ok(Json(GetInstanceResponse {
        name: context.instance_name,
        version: env!("CARGO_PKG_VERSION"),
        needs_setup,
        web_sentry_dsn: context.apps_sentry.web_dsn,
        mobile_sentry_dsn: context.apps_sentry.mobile_dsn,
        sentry_environment: context.apps_sentry.environment,
    }))
}

/// The information apps need about the WatchClub instance, which they read before signing in too.
#[derive(Serialize, ToSchema)]
#[schema(as = Instance)]
struct GetInstanceResponse {
    /// The Instance Name, which the host chooses
    #[schema(value_type = String)]
    name: Arc<str>,
    /// The server's version
    version: &'static str,
    /// Whether Setup still has to create the Instance Administrator
    needs_setup: bool,
    /// The Sentry DSN the web app reports its errors to, or null when it reports none
    #[schema(value_type = Option<String>, required = true)]
    web_sentry_dsn: Option<Arc<str>>,
    /// The Sentry DSN the mobile apps report their crashes and errors to, or null when they report
    /// none
    #[schema(value_type = Option<String>, required = true)]
    mobile_sentry_dsn: Option<Arc<str>>,
    /// The environment the apps' Sentry reports name, as the server's do, such as `production`
    #[schema(value_type = String)]
    sentry_environment: Arc<str>,
}

/// Creates the Instance Administrator and signs the browser in as them.
#[utoipa::path(
    post,
    path = "/instance/administrator",
    request_body = CreateInstanceAdministratorRequest,
    responses(
        (status = CREATED, body = CurrentUserResponse, description = "Created, and signed in with the session cookie"),
        (status = CONFLICT, body = ErrorBody<CreateInstanceAdministratorRequestError>, description = "WatchClub already has its Instance Administrator"),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<CreateInstanceAdministratorRequestError>, description = "The username or password breaks the rules"),
    ),
)]
async fn create_instance_administrator(
    State(db): State<Pool>,
    cookie: SessionCookie,
    Json(request): Json<CreateInstanceAdministratorRequest>,
) -> Result<
    (StatusCode, CookieJar, Json<CurrentUserResponse>),
    CreateInstanceAdministratorRequestError,
> {
    let CreateInstanceAdministratorRequest {
        username,
        password,
        locale,
    } = request;
    let username = Username::parse(&username)?;
    let password = Password::parse(password)?;
    let (user, token) =
        accounts::create_instance_administrator(&db, username, password, locale).await?;
    Ok((StatusCode::CREATED, cookie.set(&token), Json(user.into())))
}

/// The Instance Administrator that Setup creates.
#[derive(Deserialize, ToSchema)]
#[schema(as = NewInstanceAdministrator)]
struct CreateInstanceAdministratorRequest {
    username: String,
    #[schema(value_type = String)]
    password: SecretString,
    /// The Locale of the visitor's browser
    locale: Locale,
}

/// The failures of a request to create the Instance Administrator.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum CreateInstanceAdministratorRequestError {
    #[error(transparent)]
    InvalidUsername {
        #[from]
        reason: UsernameError,
    },
    #[error(transparent)]
    InvalidPassword {
        #[from]
        reason: PasswordError,
    },
    #[error("WatchClub already has its Instance Administrator")]
    InstanceAdministratorAlreadyExists,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
}

impl From<CreateInstanceAdministratorError> for CreateInstanceAdministratorRequestError {
    fn from(error: CreateInstanceAdministratorError) -> Self {
        match error {
            CreateInstanceAdministratorError::AlreadyExists => {
                Self::InstanceAdministratorAlreadyExists
            }
            CreateInstanceAdministratorError::Internal(error) => Self::Internal(error),
        }
    }
}

impl IntoResponse for CreateInstanceAdministratorRequestError {
    fn into_response(self) -> Response {
        let status = match self {
            Self::InvalidUsername { .. } | Self::InvalidPassword { .. } => {
                StatusCode::UNPROCESSABLE_ENTITY
            }
            Self::InstanceAdministratorAlreadyExists => StatusCode::CONFLICT,
            Self::Internal(error) => return ApiError::from(error).into_response(),
        };
        error::response(status, &self)
    }
}
