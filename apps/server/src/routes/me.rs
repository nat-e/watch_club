//! The signed-in User, their User Preferences, with how the API sends and takes them, and their
//! password.

use std::collections::BTreeSet;

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use secrecy::SecretString;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    ApiContext,
    auth::CurrentSession,
    db::Pool,
    domain::accounts::{
        self, AudioLanguage, ChangePasswordError, CurrentUser, Locale, Password, TrackLanguage,
        UserId, UserPreferences,
    },
    error::{self, ApiError, ErrorBody},
    routes::{Json, users::ApiPasswordError},
};

pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new()
        .routes(routes!(get_current_user))
        .routes(routes!(update_preferences))
        .routes(routes!(change_password))
}

/// Returns the signed-in User.
#[utoipa::path(
    get,
    path = "/me",
    responses((status = OK, body = CurrentUserResponse)),
    security(("session_cookie" = []), ("session_token" = [])),
)]
async fn get_current_user(current_user: CurrentUser) -> Json<CurrentUserResponse> {
    Json(current_user.into())
}

/// Saves the signed-in User's preferences, and returns the User with the new preferences.
#[utoipa::path(
    put,
    path = "/me/preferences",
    request_body = UserPreferencesBody,
    responses((status = OK, body = CurrentUserResponse)),
    security(("session_cookie" = []), ("session_token" = [])),
)]
async fn update_preferences(
    State(db): State<Pool>,
    current_user: CurrentUser,
    Json(preferences): Json<UserPreferencesBody>,
) -> Result<Json<CurrentUserResponse>, ApiError> {
    let current_user =
        accounts::save_preferences(&db, current_user.id, &preferences.into()).await?;
    Ok(Json(current_user.into()))
}

/// Changes the signed-in User's password, and signs them out on their other devices.
#[utoipa::path(
    put,
    path = "/me/password",
    request_body = ChangePasswordRequest,
    responses(
        (status = NO_CONTENT, description = "Changed"),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<ChangePasswordRequestError>, description = "The current password is wrong, or the new one breaks the rules"),
    ),
    security(("session_cookie" = []), ("session_token" = [])),
)]
async fn change_password(
    State(db): State<Pool>,
    session: CurrentSession,
    Json(request): Json<ChangePasswordRequest>,
) -> Result<StatusCode, ChangePasswordRequestError> {
    let new_password = Password::parse(request.new_password).map_err(ApiPasswordError::from)?;
    accounts::change_password(
        &db,
        session.user.id,
        &session.token,
        request.current_password,
        new_password,
    )
    .await?;
    Ok(StatusCode::NO_CONTENT)
}

/// The signed-in User's current password, and the one they choose instead.
#[derive(Deserialize, ToSchema)]
#[schema(as = PasswordChange)]
struct ChangePasswordRequest {
    #[schema(value_type = String)]
    current_password: SecretString,
    #[schema(value_type = String)]
    new_password: SecretString,
}

/// The failures of a request to change the signed-in User's password.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum ChangePasswordRequestError {
    #[error("wrong current password")]
    WrongPassword,
    /// The new password breaks the rules
    #[error(transparent)]
    InvalidPassword {
        #[from]
        reason: ApiPasswordError,
    },
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
}

impl From<ChangePasswordError> for ChangePasswordRequestError {
    fn from(error: ChangePasswordError) -> Self {
        match error {
            ChangePasswordError::WrongPassword => Self::WrongPassword,
            ChangePasswordError::Internal(error) => Self::Internal(error),
        }
    }
}

impl IntoResponse for ChangePasswordRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::WrongPassword | Self::InvalidPassword { .. } => {
                error::response(StatusCode::UNPROCESSABLE_ENTITY, &self)
            }
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}

/// The signed-in User, including what only this User can see: their User Preferences.
#[derive(Serialize, ToSchema)]
#[schema(as = CurrentUser)]
pub(super) struct CurrentUserResponse {
    id: UserId,
    username: String,
    is_instance_administrator: bool,
    preferences: UserPreferencesBody,
}

impl From<CurrentUser> for CurrentUserResponse {
    fn from(current_user: CurrentUser) -> Self {
        Self {
            id: current_user.id,
            username: current_user.username,
            is_instance_administrator: current_user.is_instance_administrator,
            preferences: current_user.preferences.into(),
        }
    }
}

/// A User's personal choices that shape their WatchClub experience.
#[derive(Serialize, Deserialize, ToSchema)]
#[schema(as = UserPreferences)]
struct UserPreferencesBody {
    /// The User's language and country for WatchClub's interface
    locale: Locale,
    /// The User's default language for video playback
    audio_language: AudioLanguage,
    /// The User's default subtitle language for video playback, or none for no subtitles
    // Required even though it can be null, so that leaving it out doesn't turn subtitles off
    #[serde(deserialize_with = "Option::deserialize")]
    #[schema(required = true)]
    subtitle_language: Option<TrackLanguage>,
    /// The audio languages in which the User watches videos without subtitles
    languages_without_subtitles: BTreeSet<TrackLanguage>,
}

impl From<UserPreferences> for UserPreferencesBody {
    fn from(preferences: UserPreferences) -> Self {
        Self {
            locale: preferences.locale,
            audio_language: preferences.audio_language,
            subtitle_language: preferences.subtitle_language,
            languages_without_subtitles: preferences.languages_without_subtitles,
        }
    }
}

impl From<UserPreferencesBody> for UserPreferences {
    fn from(body: UserPreferencesBody) -> Self {
        Self {
            locale: body.locale,
            audio_language: body.audio_language,
            subtitle_language: body.subtitle_language,
            languages_without_subtitles: body.languages_without_subtitles,
        }
    }
}
