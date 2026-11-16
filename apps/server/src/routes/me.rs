//! The signed-in User, and their User Preferences.

use axum::extract::State;
use serde::Deserialize;
use sqlx::PgPool;
use utoipa::ToSchema;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    auth::CurrentUser,
    domain::accounts::{self, Locale, User},
    error::ApiError,
    routes::Json,
};

pub(super) fn routes() -> OpenApiRouter<PgPool> {
    OpenApiRouter::new()
        .routes(routes!(get_current_user))
        .routes(routes!(update_preferences))
}

/// Returns the signed-in User.
#[utoipa::path(
    get,
    path = "/me",
    responses((status = OK, body = User)),
    security(("session_cookie" = []), ("session_token" = [])),
)]
async fn get_current_user(CurrentUser(user): CurrentUser) -> Json<User> {
    Json(user)
}

/// Saves the signed-in User's preferences, and returns the User with them.
#[utoipa::path(
    put,
    path = "/me/preferences",
    request_body = UpdatePreferencesRequest,
    responses((status = OK, body = User)),
    security(("session_cookie" = []), ("session_token" = [])),
)]
async fn update_preferences(
    State(db): State<PgPool>,
    CurrentUser(user): CurrentUser,
    Json(preferences): Json<UpdatePreferencesRequest>,
) -> Result<Json<User>, ApiError> {
    let user = accounts::change_locale(&db, user.id, preferences.locale).await?;
    Ok(Json(user))
}

/// A User's personal choices that shape their WatchClub experience.
#[derive(Deserialize, ToSchema)]
#[schema(as = UserPreferences)]
struct UpdatePreferencesRequest {
    locale: Locale,
}
