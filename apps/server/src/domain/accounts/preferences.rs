//! User Preferences: a User's personal choices that shape their WatchClub experience.

use anyhow::Context;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use utoipa::ToSchema;

use super::{User, UserId};
use crate::domain::InternalError;

/// A language and country preference.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[sqlx(type_name = "text")]
pub enum Locale {
    #[serde(rename = "en-US")]
    #[sqlx(rename = "en-US")]
    EnUs,
    #[serde(rename = "fr-FR")]
    #[sqlx(rename = "fr-FR")]
    FrFr,
}

/// Changes the User's language and country, and returns the updated User.
pub async fn change_locale(
    db: &PgPool,
    user: UserId,
    locale: Locale,
) -> Result<User, InternalError> {
    let user = sqlx::query_as!(
        User,
        r#"
        UPDATE users SET locale = $2 WHERE id = $1
        RETURNING id, username, locale, is_instance_administrator
        "#,
        user as UserId,
        locale as Locale,
    )
    .fetch_one(db)
    .await
    .context("failed to change the User's locale")?;
    Ok(user)
}
