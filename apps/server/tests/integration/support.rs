//! Test data, inserted directly like the Elixir app's generators, and the client that calls the
//! API.

mod client;
mod database;
pub mod fake_tmdb;

use std::process::Command;

use sqlx::postgres::PgBindIterExt;
use watch_club::{
    db::Pool,
    domain::{
        accounts::{AudioLanguage, CurrentUser, Locale, TrackLanguage, UserId, UserPreferences},
        contents::MetadataProviders,
    },
    jobs::JobContext,
};

pub use self::{client::Client, database::TestDatabase, fake_tmdb::FakeTmdb};

/// Every test User's password
pub const PASSWORD: &str = "passw0rd";

/// A database URL nothing listens on, so a server that gets past its settings fails fast
pub const UNREACHABLE_DATABASE_URL: &str = "postgres://localhost:1/watch_club";

/// Runs the server's binary with only these environment variables, as tests can't change their
/// own process's variables without `unsafe`, and returns what it printed when it failed to start.
pub fn server_startup_error(vars: &[(&str, &str)]) -> String {
    let output = Command::new(env!("CARGO_BIN_EXE_watch_club"))
        .env_clear()
        .envs(vars.iter().copied())
        .output()
        .unwrap();
    assert!(!output.status.success());
    String::from_utf8(output.stderr).unwrap()
}

/// Returns the context jobs run with: this database, and a TMDB that nothing answers.
pub fn job_context(db: &Pool) -> JobContext {
    JobContext {
        db: db.clone(),
        metadata_providers: MetadataProviders {
            tmdb: fake_tmdb::unreachable(),
        },
    }
}

/// Creates a User who signs in with `PASSWORD`, with a new User's preferences in English.
pub async fn create_user(db: &Pool, username: &str) -> CurrentUser {
    insert_user(db, username, false).await
}

/// Creates the Instance Administrator, who signs in with `PASSWORD`.
pub async fn create_instance_administrator(db: &Pool) -> CurrentUser {
    insert_user(db, "admin", true).await
}

async fn insert_user(db: &Pool, username: &str, is_instance_administrator: bool) -> CurrentUser {
    let preferences = UserPreferences::new(Locale::EnUs);
    let id = sqlx::query_scalar!(
        r#"
        INSERT INTO users (
            username, password_hash, locale, audio_language, subtitle_language,
            languages_without_subtitles, is_instance_administrator
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING id
        "#,
        username,
        password_auth::generate_hash(PASSWORD),
        preferences.locale as Locale,
        preferences.audio_language as AudioLanguage,
        preferences.subtitle_language as Option<TrackLanguage>,
        preferences.languages_without_subtitles.iter().bind_iter() as _,
        is_instance_administrator,
    )
    .fetch_one(db)
    .await
    .unwrap();
    CurrentUser {
        id,
        username: username.to_owned(),
        is_instance_administrator,
        preferences,
    }
}

/// Ends the User's sessions as if their lifetime had run out.
pub async fn expire_sessions(db: &Pool, user: UserId) {
    sqlx::query!(
        "UPDATE sessions SET expires_at = now() - interval '1 second' WHERE user_id = $1",
        user as UserId,
    )
    .execute(db)
    .await
    .unwrap();
}
