//! Users: their usernames and passwords, the list of Users, and the Password Reset Links that let a
//! User who forgot their password choose a new one.
//!
//! Rare races are accepted rather than prevented with row locks: a device that signs in with the
//! old password while it changes, in the moment the server checks it, keeps its session, and a
//! change and a reset of the same password at the same instant can fail.

use std::fmt;

use anyhow::Context;
use jiff::{SignedDuration, Timestamp};
use secrecy::{ExposeSecret, SecretString};
use serde::{Deserialize, Serialize};
use sqlx::postgres::PgBindIterExt;
use sqlx_otel::QueryAnnotateExt;
use tokio::sync::Semaphore;
use tracing::{Instrument, Level};
use utoipa::ToSchema;
use uuid::Uuid;

use super::{
    preferences::{AudioLanguage, Locale, TrackLanguage, UserPreferences},
    sessions::SessionToken,
    token::SecretToken,
};
use crate::db::{Pool, Transaction};

/// The time a Password Reset Link works for, from its creation.
const PASSWORD_RESET_LINK_LIFETIME: SignedDuration = SignedDuration::from_hours(24 * 3);

/// The unique ID of a User.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[sqlx(transparent)]
pub struct UserId(Uuid);

impl fmt::Display for UserId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(f)
    }
}

/// The signed-in User, including what only this User can see: their User Preferences.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CurrentUser {
    pub id: UserId,
    pub username: String,
    pub is_instance_administrator: bool,
    pub preferences: UserPreferences,
}

/// A User as the list of Users shows them.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct User {
    pub id: UserId,
    pub username: String,
    pub is_instance_administrator: bool,
    /// When they created their account
    #[schema(value_type = String, format = DateTime)]
    pub member_since: Timestamp,
}

/// A User as `users` stores them, which queries select into to return the current User.
pub(super) struct UserRow {
    pub(super) id: UserId,
    pub(super) username: String,
    pub(super) locale: Locale,
    pub(super) audio_language: AudioLanguage,
    pub(super) subtitle_language: Option<TrackLanguage>,
    pub(super) languages_without_subtitles: Vec<TrackLanguage>,
    pub(super) is_instance_administrator: bool,
}

impl From<UserRow> for CurrentUser {
    fn from(row: UserRow) -> Self {
        Self {
            id: row.id,
            username: row.username,
            is_instance_administrator: row.is_instance_administrator,
            preferences: UserPreferences {
                locale: row.locale,
                audio_language: row.audio_language,
                subtitle_language: row.subtitle_language,
                languages_without_subtitles: row.languages_without_subtitles.into_iter().collect(),
            },
        }
    }
}

/// A username that follows the rules: 3 to 30 lowercase letters, digits or underscores. Spaces
/// around it are trimmed.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Username(String);

impl Username {
    pub const MIN_LENGTH: usize = 3;
    pub const MAX_LENGTH: usize = 30;

    /// Trims the text and checks it follows the rules.
    pub fn parse(text: &str) -> Result<Self, ParseUsernameError> {
        let username = text.trim();
        let length = username.chars().count();
        if length == 0 {
            return Err(ParseUsernameError::Missing);
        }
        if length < Self::MIN_LENGTH {
            return Err(ParseUsernameError::TooShort {
                min: Self::MIN_LENGTH,
            });
        }
        if length > Self::MAX_LENGTH {
            return Err(ParseUsernameError::TooLong {
                max: Self::MAX_LENGTH,
            });
        }
        let is_allowed = |c: char| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_';
        if !username.chars().all(is_allowed) {
            return Err(ParseUsernameError::InvalidCharacters);
        }
        Ok(Self(username.to_owned()))
    }

    /// Returns the username, such as `ada`.
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// The reason a text isn't a username that follows the rules.
#[derive(Clone, Debug, PartialEq, Eq, thiserror::Error)]
pub enum ParseUsernameError {
    #[error("the username is missing")]
    Missing,
    #[error("the username is shorter than {min} characters")]
    TooShort { min: usize },
    #[error("the username is longer than {max} characters")]
    TooLong { max: usize },
    /// Characters other than lowercase letters, digits and underscores
    #[error("the username has characters other than lowercase letters, digits and underscores")]
    InvalidCharacters,
}

/// A new password: at least 8 characters, kept exactly as typed.
#[derive(Debug)]
pub struct Password(SecretString);

impl Password {
    pub const MIN_LENGTH: usize = 8;

    /// Checks the text follows the rules.
    pub fn parse(text: SecretString) -> Result<Self, ParsePasswordError> {
        let length = text.expose_secret().chars().count();
        if length == 0 {
            return Err(ParsePasswordError::Missing);
        }
        if length < Self::MIN_LENGTH {
            return Err(ParsePasswordError::TooShort {
                min: Self::MIN_LENGTH,
            });
        }
        Ok(Self(text))
    }

    /// Returns the password's hash, with its algorithm, settings and a random salt, which takes a
    /// moment on purpose.
    pub(super) async fn hash(self) -> String {
        hash_slowly(move || password_auth::generate_hash(self.0.expose_secret())).await
    }
}

/// The reason a text isn't a password that follows the rules.
#[derive(Clone, Debug, PartialEq, Eq, thiserror::Error)]
pub enum ParsePasswordError {
    #[error("the password is missing")]
    Missing,
    #[error("the password is shorter than {min} characters")]
    TooShort { min: usize },
}

/// Inserts a User in the transaction, with a new User's preferences for their Locale, and returns
/// them as the current User. Fails with a unique violation when another User has the username, or
/// when the User would be a second Instance Administrator. The caller hashes the password first,
/// which takes a moment, so the transaction doesn't hold its locks that long.
pub(super) async fn insert(
    transaction: &mut Transaction,
    username: &Username,
    password_hash: String,
    locale: Locale,
    is_instance_administrator: bool,
) -> Result<CurrentUser, sqlx::Error> {
    let preferences = UserPreferences::new(locale);
    let row = sqlx::query_as!(
        UserRow,
        r#"
        INSERT INTO users (
            username, password_hash, locale, audio_language, subtitle_language,
            languages_without_subtitles, is_instance_administrator
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING id, username, locale, audio_language, subtitle_language,
            languages_without_subtitles, is_instance_administrator
        "#,
        username.0,
        password_hash,
        preferences.locale as Locale,
        preferences.audio_language as AudioLanguage,
        preferences.subtitle_language as Option<TrackLanguage>,
        preferences.languages_without_subtitles.iter().bind_iter() as _,
        is_instance_administrator,
    )
    .with_operation("INSERT", "users")
    .fetch_one(&mut *transaction)
    .await?;
    Ok(CurrentUser::from(row))
}

/// Returns every User, the first to join first.
#[tracing::instrument(skip_all)]
pub async fn list(db: &Pool) -> anyhow::Result<Vec<User>> {
    let rows = sqlx::query!(
        r#"
        SELECT id, username, is_instance_administrator, inserted_at
        FROM users
        ORDER BY inserted_at, id
        "#
    )
    .with_operation("SELECT", "users")
    .fetch_all(db)
    .await
    .context("failed to list the Users")?;
    let users = rows
        .into_iter()
        .map(|row| User {
            id: row.id,
            username: row.username,
            is_instance_administrator: row.is_instance_administrator,
            member_since: row.inserted_at.to_jiff(),
        })
        .collect();
    Ok(users)
}

/// The reason a User wasn't deleted.
#[derive(Debug, thiserror::Error)]
pub enum DeleteUserError {
    #[error("no such User")]
    NotFound,
    #[error("the Instance Administrator can't be deleted")]
    IsInstanceAdministrator,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Deletes the User, which signs them out on every device.
#[tracing::instrument(skip_all, fields(user.id = %user_id))]
pub async fn delete(db: &Pool, user_id: UserId) -> Result<(), DeleteUserError> {
    // Deletes the User unless they're the Instance Administrator, and returns them as they were
    let target = sqlx::query!(
        r#"
        WITH target AS (
            SELECT id, username, is_instance_administrator FROM users WHERE id = $1
        ),
        deleted AS (
            DELETE FROM users
            WHERE id IN (SELECT id FROM target WHERE NOT is_instance_administrator)
        )
        SELECT username AS "username!", is_instance_administrator AS "is_instance_administrator!"
        FROM target
        "#,
        user_id as UserId,
    )
    .with_operation("DELETE", "users")
    .fetch_optional(db)
    .await
    .context("failed to delete a User")?;

    let Some(target) = target else {
        return Err(DeleteUserError::NotFound);
    };
    if target.is_instance_administrator {
        return Err(DeleteUserError::IsInstanceAdministrator);
    }
    tracing::event!(
        name: "accounts.user.deleted",
        Level::INFO,
        user.name = target.username,
        "deleted a User",
    );
    Ok(())
}

/// Returns the User whose username and password these are, or None. Takes about as long either
/// way.
pub(super) async fn check_credentials(
    db: &Pool,
    username: &str,
    password: SecretString,
) -> anyhow::Result<Option<CurrentUser>> {
    let Some(row) = sqlx::query!(
        r#"
        SELECT id, username, locale, audio_language, subtitle_language,
            languages_without_subtitles, is_instance_administrator, password_hash
        FROM users
        WHERE username = $1
        "#,
        username,
    )
    .with_operation("SELECT", "users")
    .fetch_optional(db)
    .await
    .context("failed to find the User signing in")?
    else {
        // Hashes the password all the same, which takes as long as checking it, so the time to
        // answer doesn't tell which usernames exist
        hash_slowly(move || password_auth::generate_hash(password.expose_secret())).await;
        return Ok(None);
    };

    if !password_matches(password, row.password_hash).await {
        return Ok(None);
    }

    Ok(Some(CurrentUser::from(UserRow {
        id: row.id,
        username: row.username,
        locale: row.locale,
        audio_language: row.audio_language,
        subtitle_language: row.subtitle_language,
        languages_without_subtitles: row.languages_without_subtitles,
        is_instance_administrator: row.is_instance_administrator,
    })))
}

/// The reason a User's password didn't change.
#[derive(Debug, thiserror::Error)]
pub enum ChangePasswordError {
    /// The current password isn't the User's
    #[error("wrong current password")]
    WrongPassword,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Changes the User's password when `current_password` is theirs, and signs them out on every
/// device but the current session's. Their Password Reset Link stops working.
#[tracing::instrument(skip_all, fields(user.id = %user_id))]
pub async fn change_password(
    db: &Pool,
    user_id: UserId,
    current_session: &SessionToken,
    current_password: SecretString,
    new_password: Password,
) -> Result<(), ChangePasswordError> {
    let password_hash = sqlx::query_scalar!(
        "SELECT password_hash FROM users WHERE id = $1",
        user_id as UserId,
    )
    .with_operation("SELECT", "users")
    .fetch_one(db)
    .await
    .context("failed to find a User's password")?;
    if !password_matches(current_password, password_hash.clone()).await {
        tracing::event!(
            name: "accounts.password.change_refused",
            Level::WARN,
            "wrong current password",
        );
        return Err(ChangePasswordError::WrongPassword);
    }
    let new_password_hash = new_password.hash().await;

    // Only while the password is still the one checked, rather than one a Password Reset Link set
    // meanwhile
    let changed = sqlx::query_scalar!(
        r#"
        WITH changed AS (
            UPDATE users SET password_hash = $2
            WHERE id = $1 AND password_hash = $3
            RETURNING id
        ),
        signed_out AS (
            DELETE FROM sessions
            WHERE user_id IN (SELECT id FROM changed) AND token_hash <> $4
        ),
        cancelled AS (
            DELETE FROM password_reset_links WHERE user_id IN (SELECT id FROM changed)
        )
        SELECT EXISTS (SELECT FROM changed) AS "changed!"
        "#,
        user_id as UserId,
        new_password_hash,
        password_hash,
        &current_session.hash(),
    )
    .with_operation("UPDATE", "users")
    .fetch_one(db)
    .await
    .context("failed to change a User's password")?;
    if !changed {
        return Err(ChangePasswordError::WrongPassword);
    }

    tracing::event!(
        name: "accounts.password.changed",
        Level::INFO,
        "changed a User's password",
    );
    Ok(())
}

/// The reason a Password Reset Link wasn't created.
#[derive(Debug, thiserror::Error)]
pub enum CreatePasswordResetLinkError {
    #[error("no such User")]
    NotFound,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Creates a Password Reset Link for the User, which works once, for
/// `PASSWORD_RESET_LINK_LIFETIME`, and returns its token. It replaces the User's last link, which
/// stops working.
#[tracing::instrument(skip_all, fields(user.id = %user_id))]
pub async fn create_password_reset_link(
    db: &Pool,
    user_id: UserId,
) -> Result<SecretString, CreatePasswordResetLinkError> {
    let token =
        SecretToken::random().context("failed to generate a Password Reset Link's token")?;
    // The database's clock, which resetting checks the expiry against
    let created = sqlx::query!(
        r#"
        INSERT INTO password_reset_links (user_id, token_hash, expires_at)
        VALUES ($1, $2, now() + make_interval(secs => $3))
        ON CONFLICT (user_id) DO UPDATE
        SET token_hash = excluded.token_hash, expires_at = excluded.expires_at
        "#,
        user_id as UserId,
        &token.hash(),
        PASSWORD_RESET_LINK_LIFETIME.as_secs_f64(),
    )
    .with_operation("INSERT", "password_reset_links")
    .execute(db)
    .await;
    match created {
        Ok(_) => {}
        Err(sqlx::Error::Database(error)) if error.is_foreign_key_violation() => {
            return Err(CreatePasswordResetLinkError::NotFound);
        }
        Err(error) => {
            let error = anyhow::Error::new(error).context("failed to create a Password Reset Link");
            return Err(error.into());
        }
    }

    tracing::event!(
        name: "accounts.password_reset_link.created",
        Level::INFO,
        "created a Password Reset Link",
    );
    Ok(token.encode().into())
}

/// Returns the username of the User whose password the Password Reset Link with this token resets,
/// or None when the link no longer works: it expired, was used or replaced, or never existed.
#[tracing::instrument(skip_all)]
pub async fn password_reset_username(db: &Pool, token: &str) -> anyhow::Result<Option<String>> {
    let Some(token) = SecretToken::decode(token) else {
        return Ok(None);
    };
    let username = sqlx::query_scalar!(
        r#"
        SELECT u.username
        FROM password_reset_links l
        JOIN users u ON u.id = l.user_id
        WHERE l.token_hash = $1 AND l.expires_at > now()
        "#,
        &token.hash(),
    )
    .with_operation("SELECT", "password_reset_links")
    .fetch_optional(db)
    .await
    .context("failed to check a Password Reset Link")?;
    Ok(username)
}

/// The reason a password wasn't reset.
#[derive(Debug, thiserror::Error)]
pub enum ResetPasswordError {
    /// The Password Reset Link expired, was used or replaced, or never existed
    #[error("the Password Reset Link no longer works")]
    LinkNoLongerWorks,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Sets the password of the User whose Password Reset Link has this token, and signs them out on
/// every device: they then sign in with the new password. The link stops working.
#[tracing::instrument(skip_all)]
pub async fn reset_password(
    db: &Pool,
    token: &str,
    password: Password,
) -> Result<(), ResetPasswordError> {
    let Some(token) = SecretToken::decode(token) else {
        return Err(ResetPasswordError::LinkNoLongerWorks);
    };
    let password_hash = password.hash().await;

    // Deletes the link as it uses it, so that it works once, even for two requests at once
    let user = sqlx::query!(
        r#"
        WITH link AS (
            DELETE FROM password_reset_links
            WHERE token_hash = $1 AND expires_at > now()
            RETURNING user_id
        ),
        changed AS (
            UPDATE users SET password_hash = $2
            WHERE id IN (SELECT user_id FROM link)
            RETURNING id, username
        ),
        signed_out AS (
            DELETE FROM sessions WHERE user_id IN (SELECT id FROM changed)
        )
        SELECT id, username FROM changed
        "#,
        &token.hash(),
        password_hash,
    )
    .with_operation("UPDATE", "users")
    .fetch_optional(db)
    .await
    .context("failed to reset a password")?;
    let Some(user) = user else {
        return Err(ResetPasswordError::LinkNoLongerWorks);
    };

    tracing::event!(
        name: "accounts.password.reset",
        Level::INFO,
        user.id = %user.id,
        user.name = user.username,
        "reset a User's password with a Password Reset Link",
    );
    Ok(())
}

/// Returns whether the password is the one `password_hash` was made from, which takes a moment on
/// purpose.
async fn password_matches(password: SecretString, password_hash: String) -> bool {
    hash_slowly(move || {
        password_auth::verify_password(password.expose_secret(), &password_hash).is_ok()
    })
    .await
}

/// The slots for hashing passwords. Hashing one takes a CPU core and about 19 MiB for a moment,
/// so only this many run at once and a flood of sign-ins waits in line instead of using up the
/// server.
static HASHING: Semaphore = Semaphore::const_new(4);

/// Runs `work`, which hashes a password and is slow on purpose, off the async threads, waiting
/// for one of the `HASHING` slots first.
async fn hash_slowly<T: Send + 'static>(work: impl FnOnce() -> T + Send + 'static) -> T {
    // Two spans, so that traces tell a queue of sign-ins from slow hashing
    let slot = HASHING
        .acquire()
        .instrument(tracing::info_span!("wait_for_hashing_slot"))
        .await
        .expect("the semaphore is never closed");
    // Under the caller's span, and ended by the work rather than by the request, which may be
    // dropped before
    let hashing = tracing::info_span!("hash_password");
    tokio::task::spawn_blocking(move || {
        // Held until the work ends, even when the request is dropped before
        let _slot = slot;
        hashing.in_scope(work)
    })
    .await
    .expect("hashing a password doesn't panic")
}

#[cfg(test)]
mod tests {
    use std::{
        sync::atomic::{AtomicUsize, Ordering},
        thread,
        time::Duration,
    };

    use super::*;

    #[tokio::test]
    async fn hashing_runs_four_at_a_time() {
        static RUNNING: AtomicUsize = AtomicUsize::new(0);
        static MOST_AT_ONCE: AtomicUsize = AtomicUsize::new(0);

        let jobs: Vec<_> = (0..8)
            .map(|_| {
                tokio::spawn(hash_slowly(|| {
                    let running = RUNNING.fetch_add(1, Ordering::SeqCst) + 1;
                    MOST_AT_ONCE.fetch_max(running, Ordering::SeqCst);
                    thread::sleep(Duration::from_millis(100));
                    RUNNING.fetch_sub(1, Ordering::SeqCst);
                }))
            })
            .collect();
        for job in jobs {
            job.await.unwrap();
        }

        assert_eq!(MOST_AT_ONCE.load(Ordering::SeqCst), 4);
    }
}
