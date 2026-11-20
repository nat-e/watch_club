//! Test data, inserted directly like the Elixir app's generators, and the client that calls the
//! API.

mod client;
mod database;
pub mod fake_hardcover;
pub mod fake_servarr;
pub mod fake_sportarr;
pub mod fake_tmdb;

use std::process::Command;

use secrecy::ExposeSecret;
use sqlx::postgres::PgBindIterExt;
use watch_club::{
    api_client::HttpClient,
    db::Pool,
    domain::{
        accounts::{
            invitations::InvitationId,
            preferences::{AudioLanguage, Locale, TrackLanguage, UserPreferences},
            users::{self, CurrentUser, UserId},
        },
        contents::metadata::MetadataProviders,
    },
    jobs::JobContext,
    utils::encryption::{EncryptedSecret, EncryptionKey},
};

pub use self::{
    client::Client, database::TestDatabase, fake_hardcover::FakeHardcover,
    fake_servarr::FakeServarr, fake_sportarr::FakeSportarr, fake_tmdb::FakeTmdb,
};

/// Every test User's password
pub const PASSWORD: &str = "passw0rd";

/// The key the test apps encrypt the secrets they store with
pub const ENCRYPTION_KEY: &str = "q5OMH0wWDIQnaWrTU+zAPahOTWVdTpqo8uUpKzVZ1Ag=";

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

/// Returns the key the test apps encrypt the secrets they store with, `ENCRYPTION_KEY`.
pub fn encryption_key() -> EncryptionKey {
    EncryptionKey::from_base64(ENCRYPTION_KEY).unwrap()
}

/// Returns a key other than `ENCRYPTION_KEY`, as when the host changed it: it can't decrypt the
/// secrets that the test apps stored.
pub fn another_encryption_key() -> EncryptionKey {
    EncryptionKey::from_base64("fRBMVNwYcSGHtIBQQ9gNFrz7cnWZsvMBYFxufHx2N+k=").unwrap()
}

/// Returns the connections that the test apps call other services through. Each test gets its own,
/// as connections don't outlive the test's runtime.
pub fn http_client() -> HttpClient {
    HttpClient::new().unwrap()
}

/// Returns the API key that the Source with this ID saved, as the table stores it.
pub async fn saved_api_key(db: &Pool, source_id: &str) -> EncryptedSecret {
    sqlx::query_scalar!(
        r#"SELECT api_key_encrypted AS "api_key!" FROM sources WHERE id = $1::text::uuid"#,
        source_id,
    )
    .fetch_one(db)
    .await
    .unwrap()
}

/// Returns the context jobs run with: this database, and Metadata Providers that nothing answers.
pub fn job_context(db: &Pool) -> JobContext {
    JobContext {
        db: db.clone(),
        metadata_providers: unreachable_metadata_providers(),
    }
}

/// Returns the Metadata Providers of an instance whose calls to them fail, as nothing answers them.
pub fn unreachable_metadata_providers() -> MetadataProviders {
    MetadataProviders {
        tmdb: fake_tmdb::unreachable(),
        sportarr: fake_sportarr::unreachable(),
        hardcover: fake_hardcover::unreachable(),
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

/// Creates the Instance Administrator, and returns a client signed in as them.
pub async fn admin_browser(db: &Pool) -> Client {
    let admin = create_instance_administrator(db).await;
    let mut browser = Client::new(db);
    browser.sign_in(&admin).await;
    browser
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
pub async fn expire_sessions(db: &Pool, user_id: UserId) {
    sqlx::query!(
        "UPDATE sessions SET expires_at = now() - interval '1 second' WHERE user_id = $1",
        user_id as UserId,
    )
    .execute(db)
    .await
    .unwrap();
}

/// Creates an Invitation with this code, which works for a week, and returns its ID.
pub async fn create_invitation(db: &Pool, code: &str, max_uses: Option<i64>) -> InvitationId {
    sqlx::query_scalar!(
        r#"
        INSERT INTO invitations (code, max_uses, expires_at)
        VALUES ($1, $2, now() + interval '7 days')
        RETURNING id
        "#,
        code,
        max_uses,
    )
    .fetch_one(db)
    .await
    .unwrap()
}

/// Makes the Invitation expire, as if its time had run out.
pub async fn expire_invitation(db: &Pool, invitation_id: InvitationId) {
    sqlx::query!(
        "UPDATE invitations SET expires_at = now() - interval '1 second' WHERE id = $1",
        invitation_id as InvitationId,
    )
    .execute(db)
    .await
    .unwrap();
}

/// Creates a Password Reset Link for the User, as the Instance Administrator does, and returns its
/// token.
pub async fn create_password_reset_link(db: &Pool, user_id: UserId) -> String {
    let token = users::create_password_reset_link(db, user_id)
        .await
        .unwrap();
    token.expose_secret().to_owned()
}

/// Makes the User's Password Reset Link expire, as if its time had run out.
pub async fn expire_password_reset_link(db: &Pool, user_id: UserId) {
    sqlx::query!(
        "UPDATE password_reset_links SET expires_at = now() - interval '1 second' WHERE user_id = $1",
        user_id as UserId,
    )
    .execute(db)
    .await
    .unwrap();
}
