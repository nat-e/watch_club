//! User Preferences: a User's personal choices that shape their WatchClub experience.

use std::collections::BTreeSet;

use anyhow::Context;
use serde::{Deserialize, Serialize};
use sqlx::postgres::PgBindIterExt;
use sqlx_otel::QueryAnnotateExt;
use utoipa::ToSchema;

use super::users::{CurrentUser, UserId, UserRow};
use crate::db::Pool;

/// A User's personal choices that shape their WatchClub experience.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UserPreferences {
    /// The User's language and country for WatchClub's interface
    pub locale: Locale,
    /// The User's default language for video playback
    pub audio_language: AudioLanguage,
    /// The User's default subtitle language for video playback, or none for no subtitles
    pub subtitle_language: Option<TrackLanguage>,
    /// The audio languages in which the User watches videos without subtitles
    pub languages_without_subtitles: BTreeSet<TrackLanguage>,
}

impl UserPreferences {
    /// Returns a new User's preferences: videos play in their original language, with subtitles in
    /// the language of the User's Locale, except when the audio is already in it.
    pub fn new(locale: Locale) -> Self {
        let language = match locale {
            Locale::EnUs => TrackLanguage::En,
            Locale::FrFr => TrackLanguage::Fr,
        };
        Self {
            locale,
            audio_language: AudioLanguage::Original,
            subtitle_language: Some(language),
            languages_without_subtitles: BTreeSet::from([language]),
        }
    }
}

/// A language and country preference.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[sqlx(type_name = "locale")]
pub enum Locale {
    #[serde(rename = "en-US")]
    #[sqlx(rename = "en-US")]
    EnUs,
    #[serde(rename = "fr-FR")]
    #[sqlx(rename = "fr-FR")]
    FrFr,
}

impl Locale {
    /// Every Locale
    pub const ALL: [Self; 2] = [Self::EnUs, Self::FrFr];

    /// Returns its BCP 47 language tag, such as `en-US`.
    pub const fn language_tag(self) -> &'static str {
        match self {
            Self::EnUs => "en-US",
            Self::FrFr => "fr-FR",
        }
    }

    /// Returns its language's ISO 639-1 code, such as `en`.
    pub const fn language(self) -> &'static str {
        match self {
            Self::EnUs => "en",
            Self::FrFr => "fr",
        }
    }

    /// Returns its country's ISO 3166-1 code, such as `US`.
    pub const fn country(self) -> &'static str {
        match self {
            Self::EnUs => "US",
            Self::FrFr => "FR",
        }
    }
}

/// A language a User can choose for audio and subtitles, as its ISO 639-1 code.
#[derive(
    Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize, sqlx::Type, ToSchema,
)]
#[serde(rename_all = "lowercase")]
#[sqlx(type_name = "text", rename_all = "lowercase")]
pub enum TrackLanguage {
    En,
    Fr,
}

/// The language a User wants to hear: the Content's original language, or a Track Language.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[serde(rename_all = "lowercase")]
#[sqlx(type_name = "text", rename_all = "lowercase")]
pub enum AudioLanguage {
    Original,
    En,
    Fr,
}

/// Saves the User's preferences, and returns the current User with the new preferences.
#[tracing::instrument(skip_all, fields(user.id = %user_id))]
pub async fn save(
    db: &Pool,
    user_id: UserId,
    preferences: &UserPreferences,
) -> anyhow::Result<CurrentUser> {
    let row = sqlx::query_as!(
        UserRow,
        r#"
        UPDATE users
        SET locale = $2,
            audio_language = $3,
            subtitle_language = $4,
            languages_without_subtitles = $5
        WHERE id = $1
        RETURNING id, username, locale, audio_language, subtitle_language,
            languages_without_subtitles, is_instance_administrator
        "#,
        user_id as UserId,
        preferences.locale as Locale,
        preferences.audio_language as AudioLanguage,
        preferences.subtitle_language as Option<TrackLanguage>,
        preferences.languages_without_subtitles.iter().bind_iter() as _,
    )
    .with_operation("UPDATE", "users")
    .fetch_one(db)
    .await
    .context("failed to save the User's preferences")?;
    Ok(row.into())
}
