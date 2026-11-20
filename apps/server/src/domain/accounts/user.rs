//! Users: their usernames and passwords, Setup, the sessions that keep them signed in, and the list
//! of Users.

use std::fmt;

use anyhow::Context;
use jiff::{SignedDuration, Timestamp};
use secrecy::{ExposeSecret, SecretString};
use serde::{Deserialize, Serialize};
use sqlx::{PgExecutor, postgres::PgBindIterExt};
use sqlx_otel::QueryAnnotateExt;
use tokio::sync::Semaphore;
use tracing::{Instrument, Level};
use utoipa::ToSchema;
use uuid::Uuid;

use super::{AudioLanguage, Locale, TrackLanguage, UserPreferences, token::SecretToken};
use crate::{
    db::{Pool, Transaction},
    domain::InternalError,
};

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
    pub fn parse(text: &str) -> Result<Self, UsernameError> {
        let username = text.trim();
        let length = username.chars().count();
        if length == 0 {
            return Err(UsernameError::Missing);
        }
        if length < Self::MIN_LENGTH {
            return Err(UsernameError::TooShort {
                min: Self::MIN_LENGTH,
            });
        }
        if length > Self::MAX_LENGTH {
            return Err(UsernameError::TooLong {
                max: Self::MAX_LENGTH,
            });
        }
        let is_allowed = |c: char| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_';
        if !username.chars().all(is_allowed) {
            return Err(UsernameError::InvalidCharacters);
        }
        Ok(Self(username.to_owned()))
    }
}

/// Potential errors when parsing Usernames
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
#[schema(as = UsernameProblem)]
pub enum UsernameError {
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
    pub fn parse(text: SecretString) -> Result<Self, PasswordError> {
        let length = text.expose_secret().chars().count();
        if length == 0 {
            return Err(PasswordError::Missing);
        }
        if length < Self::MIN_LENGTH {
            return Err(PasswordError::TooShort {
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

/// Potential errors when parsing Passwords
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
#[schema(as = PasswordProblem)]
pub enum PasswordError {
    #[error("the password is missing")]
    Missing,
    #[error("the password is shorter than {min} characters")]
    TooShort { min: usize },
}

/// Returns `true` once Setup has created the Instance Administrator.
#[tracing::instrument(skip_all)]
pub async fn has_instance_administrator(db: &Pool) -> Result<bool, InternalError> {
    let exists = sqlx::query_scalar!(
        r#"SELECT EXISTS (SELECT FROM users WHERE is_instance_administrator) AS "exists!""#
    )
    .with_operation("SELECT", "users")
    .fetch_one(db)
    .await
    .context("failed to check for the Instance Administrator")?;
    Ok(exists)
}

/// The reason the Instance Administrator wasn't created.
#[derive(Debug, thiserror::Error)]
pub enum CreateInstanceAdministratorError {
    #[error("WatchClub already has its Instance Administrator")]
    AlreadyExists,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

impl From<InternalError> for CreateInstanceAdministratorError {
    fn from(error: InternalError) -> Self {
        Self::Internal(error.0)
    }
}

/// Creates the Instance Administrator, with a new User's preferences for their Locale, signs them in
/// on a new device and returns them as the current User.
#[tracing::instrument(skip_all)]
pub async fn create_instance_administrator(
    db: &Pool,
    username: Username,
    password: Password,
    locale: Locale,
) -> Result<(CurrentUser, SessionToken), CreateInstanceAdministratorError> {
    let password_hash = password.hash().await;

    let mut transaction = db.begin().await.context("failed to start a transaction")?;
    let inserted = insert_user(&mut transaction, &username, password_hash, locale, true).await;
    let admin = match inserted {
        Ok(admin) => admin,
        // Users only exist once Setup created the Instance Administrator, so another one, or a
        // User with the same username, means Setup already ran
        Err(sqlx::Error::Database(error)) if error.is_unique_violation() => {
            tracing::event!(
                name: "accounts.instance_administrator.refused",
                Level::WARN,
                user.name = username.0,
                "refused to create a second Instance Administrator",
            );
            return Err(CreateInstanceAdministratorError::AlreadyExists);
        }
        Err(error) => {
            let error =
                anyhow::Error::new(error).context("failed to create the Instance Administrator");
            return Err(error.into());
        }
    };
    let token = create_session(&mut transaction, admin.id).await?;
    transaction
        .commit()
        .await
        .context("failed to create the Instance Administrator")?;
    tracing::event!(
        name: "accounts.instance_administrator.created",
        Level::INFO,
        user.id = %admin.id,
        user.name = admin.username,
        "created the Instance Administrator",
    );
    Ok((admin, token))
}

/// Inserts a User in the transaction, with a new User's preferences for their Locale, and returns
/// them as the current User. Fails with a unique violation when another User has the username, or
/// when the User would be a second Instance Administrator. The caller hashes the password first,
/// which takes a moment, so the transaction doesn't hold its locks that long.
pub(super) async fn insert_user(
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
pub async fn list_users(db: &Pool) -> Result<Vec<User>, InternalError> {
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
    UserNotFound,
    #[error("the Instance Administrator can't be deleted")]
    CannotDeleteAdministrator,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Deletes the User, which signs them out on every device.
#[tracing::instrument(skip_all, fields(user.id = %user_id))]
pub async fn delete_user(db: &Pool, user_id: UserId) -> Result<(), DeleteUserError> {
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
        return Err(DeleteUserError::UserNotFound);
    };
    if target.is_instance_administrator {
        return Err(DeleteUserError::CannotDeleteAdministrator);
    }
    tracing::event!(
        name: "accounts.user.deleted",
        Level::INFO,
        user.name = target.username,
        "deleted a User",
    );
    Ok(())
}

/// The time signing in keeps a User signed in on a device.
pub const SESSION_LIFETIME: SignedDuration = SignedDuration::from_hours(24 * 30);

/// The secret that keeps a User signed in on one device. The database only stores its hash, so
/// a leaked database signs nobody in.
#[derive(Debug)]
pub struct SessionToken(SecretToken);

impl SessionToken {
    /// Reads a token in the form [`encode`](Self::encode) gives, or returns None.
    pub fn decode(text: &str) -> Option<Self> {
        SecretToken::decode(text).map(Self)
    }

    /// Returns the token as text that fits in a cookie or a header.
    pub fn encode(&self) -> String {
        self.0.encode()
    }

    pub(super) fn hash(&self) -> [u8; 32] {
        self.0.hash()
    }
}

/// Signs the User in on a new device, and returns them with their session token.
///
/// Returns None if the username or password is wrong.
#[tracing::instrument(skip_all)]
pub async fn sign_in(
    db: &Pool,
    username: &str,
    password: SecretString,
) -> Result<Option<(CurrentUser, SessionToken)>, InternalError> {
    let username = username.trim();
    let Some(user) = check_credentials(db, username, password).await? else {
        tracing::event!(
            name: "accounts.sign_in.failed",
            Level::WARN,
            user.name = username,
            "wrong username or password",
        );
        return Ok(None);
    };
    let token = create_session(db, user.id).await?;
    tracing::event!(
        name: "accounts.sign_in.succeeded",
        Level::INFO,
        user.id = %user.id,
        user.name = user.username,
        "signed in",
    );
    Ok(Some((user, token)))
}

/// Returns the User whose username and password these are, or None. Takes about as long either
/// way.
async fn check_credentials(
    db: &Pool,
    username: &str,
    password: SecretString,
) -> Result<Option<CurrentUser>, InternalError> {
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

/// Returns whether the password is the one `password_hash` was made from, which takes a moment on
/// purpose.
pub(super) async fn password_matches(password: SecretString, password_hash: String) -> bool {
    hash_slowly(move || {
        password_auth::verify_password(password.expose_secret(), &password_hash).is_ok()
    })
    .await
}

/// Returns the User the token keeps signed in, or None once their session ended or expired.
#[tracing::instrument(skip_all)]
pub async fn session_user(
    db: &Pool,
    token: &SessionToken,
) -> Result<Option<CurrentUser>, InternalError> {
    let row = sqlx::query_as!(
        UserRow,
        r#"
        SELECT u.id, u.username, u.locale, u.audio_language, u.subtitle_language,
            u.languages_without_subtitles, u.is_instance_administrator
        FROM sessions s
        JOIN users u ON u.id = s.user_id
        WHERE s.token_hash = $1 AND s.expires_at > now()
        "#,
        &token.hash(),
    )
    .with_operation("SELECT", "sessions")
    .fetch_optional(db)
    .await
    .context("failed to find the session's User")?;
    Ok(row.map(CurrentUser::from))
}

/// Signs out the device that the token keeps signed in.
#[tracing::instrument(skip_all)]
pub async fn sign_out(db: &Pool, token: &SessionToken) -> Result<(), InternalError> {
    sqlx::query!("DELETE FROM sessions WHERE token_hash = $1", &token.hash())
        .with_operation("DELETE", "sessions")
        .execute(db)
        .await
        .context("failed to end a session")?;
    Ok(())
}

/// Deletes the sessions whose lifetime has run out, and returns how many it deleted.
#[tracing::instrument(skip_all)]
pub async fn delete_expired_sessions(db: &Pool) -> Result<u64, InternalError> {
    let deleted = sqlx::query!("DELETE FROM sessions WHERE expires_at < now()")
        .with_operation("DELETE", "sessions")
        .execute(db)
        .await
        .context("failed to delete the expired sessions")?;
    Ok(deleted.rows_affected())
}

/// Creates a session that keeps the User signed in on a new device for `SESSION_LIFETIME`, and
/// returns its token.
pub(super) async fn create_session(
    db: impl PgExecutor<'_>,
    user_id: UserId,
) -> Result<SessionToken, InternalError> {
    let token = SecretToken::random()
        .map(SessionToken)
        .context("failed to generate a session token")?;
    // The database's clock, which `session_user` checks the expiry against
    sqlx::query!(
        r#"
        INSERT INTO sessions (token_hash, user_id, expires_at)
        VALUES ($1, $2, now() + make_interval(secs => $3))
        "#,
        &token.hash(),
        user_id as UserId,
        SESSION_LIFETIME.as_secs_f64(),
    )
    .execute(db)
    .await
    .context("failed to start a session")?;
    Ok(token)
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
