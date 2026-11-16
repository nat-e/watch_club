//! Test data, inserted directly like the Elixir app's generators, and the client that calls the
//! API.

mod client;

use sqlx::PgPool;
use watch_club::domain::accounts::{Locale, User, UserId};

pub use self::client::Client;

/// Every test User's password
pub const PASSWORD: &str = "passw0rd";

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
