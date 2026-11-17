//! The WatchClub instance: whether it's set up yet, and Setup, where its first visitor creates
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
    AppState,
    auth::SessionCookie,
    db::Pool,
    domain::{
        InternalError,
        accounts::{
            self, CreateInstanceAdministratorError, Locale, Password, PasswordError, User,
            Username, UsernameError,
        },
    },
    error::{self, ApiError, ErrorBody},
    routes::Json,
};

pub(super) fn routes() -> OpenApiRouter<AppState> {
    OpenApiRouter::new()
        .routes(routes!(get_instance))
        .routes(routes!(create_instance_administrator))
}

/// Returns the information apps need about the WatchClub instance before signing in.
#[utoipa::path(get, path = "/instance", responses((status = OK, body = GetInstanceResponse)))]
async fn get_instance(
    State(state): State<AppState>,
) -> Result<Json<GetInstanceResponse>, ApiError> {
    let needs_setup = !accounts::has_instance_administrator(&state.db).await?;
    Ok(Json(GetInstanceResponse {
        version: env!("CARGO_PKG_VERSION"),
        needs_setup,
        web_sentry_dsn: state.apps_sentry.web_dsn,
        mobile_sentry_dsn: state.apps_sentry.mobile_dsn,
        sentry_environment: state.apps_sentry.environment,
    }))
}

/// The information apps need about the WatchClub instance before signing in.
#[derive(Serialize, ToSchema)]
#[schema(as = Instance)]
struct GetInstanceResponse {
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
        (status = CREATED, body = User, description = "Created, and signed in with the session cookie"),
        (status = CONFLICT, body = ErrorBody<CreateInstanceAdministratorRequestError>, description = "WatchClub already has its Instance Administrator"),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<CreateInstanceAdministratorRequestError>, description = "The username or password breaks the rules"),
    ),
)]
async fn create_instance_administrator(
    State(db): State<Pool>,
    cookie: SessionCookie,
    Json(request): Json<CreateInstanceAdministratorRequest>,
) -> Result<(StatusCode, CookieJar, Json<User>), CreateInstanceAdministratorRequestError> {
    let (username, password, locale) = request.parse()?;
    let (user, token) =
        accounts::create_instance_administrator(&db, username, password, locale).await?;
    Ok((StatusCode::CREATED, cookie.set(&token), Json(user)))
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

impl CreateInstanceAdministratorRequest {
    /// Checks the username and password, and reports the problems with both at once.
    fn parse(
        self,
    ) -> Result<(Username, Password, Locale), CreateInstanceAdministratorRequestError> {
        match (
            Username::parse(&self.username),
            Password::parse(self.password),
        ) {
            (Ok(username), Ok(password)) => Ok((username, password, self.locale)),
            (username, password) => Err(CreateInstanceAdministratorRequestError::InvalidFields {
                username: username.err(),
                password: password.err(),
            }),
        }
    }
}

/// The failures of a request to create the Instance Administrator.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum CreateInstanceAdministratorRequestError {
    #[error("the username or password breaks the rules")]
    InvalidFields {
        #[serde(skip_serializing_if = "Option::is_none")]
        #[schema(nullable = false)]
        username: Option<UsernameError>,
        #[serde(skip_serializing_if = "Option::is_none")]
        #[schema(nullable = false)]
        password: Option<PasswordError>,
    },
    #[error("WatchClub already has its Instance Administrator")]
    InstanceAdministratorAlreadyExists,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl From<CreateInstanceAdministratorError> for CreateInstanceAdministratorRequestError {
    fn from(error: CreateInstanceAdministratorError) -> Self {
        match error {
            CreateInstanceAdministratorError::AlreadyExists => {
                Self::InstanceAdministratorAlreadyExists
            }
            CreateInstanceAdministratorError::Internal(error) => Self::Internal(error.into()),
        }
    }
}

impl IntoResponse for CreateInstanceAdministratorRequestError {
    fn into_response(self) -> Response {
        let status = match self {
            Self::InvalidFields { .. } => StatusCode::UNPROCESSABLE_ENTITY,
            Self::InstanceAdministratorAlreadyExists => StatusCode::CONFLICT,
            Self::Internal(error) => return ApiError::from(error).into_response(),
        };
        error::response(status, &self)
    }
}
