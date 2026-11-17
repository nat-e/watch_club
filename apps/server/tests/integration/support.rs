//! Test data, inserted directly like the Elixir app's generators, and the client that calls the
//! API.

mod client;

use std::process::Command;

use sqlx::PgPool;
use watch_club::domain::accounts::{Locale, User, UserId};

pub use self::client::Client;

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

/// Creates a User who signs in with `PASSWORD`.
pub async fn create_user(db: &PgPool, username: &str) -> User {
    insert_user(db, username, false).await
}

/// Creates the Instance Administrator, who signs in with `PASSWORD`.
pub async fn create_instance_administrator(db: &PgPool) -> User {
    insert_user(db, "admin", true).await
}

async fn insert_user(db: &PgPool, username: &str, is_instance_administrator: bool) -> User {
    sqlx::query_as!(
        User,
        r#"
        INSERT INTO users (username, password_hash, locale, is_instance_administrator)
        VALUES ($1, $2, $3, $4)
        RETURNING id, username, locale, is_instance_administrator
        "#,
        username,
        password_auth::generate_hash(PASSWORD),
        Locale::EnUs as Locale,
        is_instance_administrator,
    )
    .fetch_one(db)
    .await
    .unwrap()
}

/// Ends the User's sessions as if their lifetime had run out.
pub async fn expire_sessions(db: &PgPool, user: UserId) {
    sqlx::query!(
        "UPDATE sessions SET expires_at = now() - interval '1 second' WHERE user_id = $1",
        user as UserId,
    )
    .execute(db)
    .await
    .unwrap();
}
