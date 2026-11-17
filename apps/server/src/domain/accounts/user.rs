//! Users: their usernames and passwords, Setup, and the sessions that keep them signed in.

use anyhow::Context;
use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use jiff::SignedDuration;
use secrecy::{ExposeSecret, ExposeSecretMut, SecretBox, SecretString};
use serde::Serialize;
use sha2::{Digest, Sha256};
use sqlx::{PgExecutor, PgPool};
use tokio::sync::Semaphore;
use utoipa::ToSchema;
use uuid::Uuid;

use super::Locale;
use crate::domain::InternalError;

/// The unique ID of a User.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, sqlx::Type, ToSchema)]
#[sqlx(transparent)]
pub struct UserId(Uuid);

/// A person with a WatchClub account.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct User {
    pub id: UserId,
    pub username: String,
    /// The language and country WatchClub uses for them
    pub locale: Locale,
    pub is_instance_administrator: bool,
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

    fn into_inner(self) -> String {
        self.0
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

/// A password for a new account: at least 8 characters, kept exactly as typed.
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
pub async fn has_instance_administrator(db: &PgPool) -> Result<bool, InternalError> {
    let exists = sqlx::query_scalar!(
        r#"SELECT EXISTS (SELECT FROM users WHERE is_instance_administrator) AS "exists!""#
    )
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

/// Creates the Instance Administrator and signs them in on a new device.
pub async fn create_instance_administrator(
    db: &PgPool,
    username: Username,
    password: Password,
    locale: Locale,
) -> Result<(User, SessionToken), CreateInstanceAdministratorError> {
    let password_hash =
        hash_slowly(move || password_auth::generate_hash(password.0.expose_secret())).await;

    let mut transaction = db.begin().await.context("failed to start a transaction")?;
    let created = sqlx::query_as!(
        User,
        r#"
        INSERT INTO users (username, password_hash, locale, is_instance_administrator)
        VALUES ($1, $2, $3, true)
        RETURNING id, username, locale, is_instance_administrator
        "#,
        username.into_inner(),
        password_hash,
        locale as Locale,
    )
    .fetch_one(&mut *transaction)
    .await;
    let user = match created {
        Ok(user) => user,
        Err(error) => {
            // Gives the connection back before the check below takes one from the pool
            transaction
                .rollback()
                .await
                .context("failed to roll back creating the Instance Administrator")?;
            // Postgres may report the username's constraint rather than the one that allows a
            // single Instance Administrator, when Setup runs again with their username
            let is_unique_violation = matches!(
                &error,
                sqlx::Error::Database(error) if error.is_unique_violation()
            );
            if is_unique_violation && has_instance_administrator(db).await? {
                return Err(CreateInstanceAdministratorError::AlreadyExists);
            }
            return Err(anyhow::Error::new(error)
                .context("failed to create the Instance Administrator")
                .into());
        }
    };
    let token = create_session(&mut *transaction, user.id).await?;
    transaction
        .commit()
        .await
        .context("failed to create the Instance Administrator")?;
    Ok((user, token))
}

/// The time signing in keeps a User signed in on a device.
pub const SESSION_LIFETIME: SignedDuration = SignedDuration::from_hours(24 * 30);

/// The secret that keeps a User signed in on one device. The database only stores its hash, so
/// a leaked database signs nobody in.
#[derive(Debug)]
pub struct SessionToken(SecretBox<[u8; 32]>);

impl SessionToken {
    fn random() -> Result<Self, getrandom::Error> {
        let mut bytes = SecretBox::<[u8; 32]>::default();
        getrandom::fill(bytes.expose_secret_mut())?;
        Ok(Self(bytes))
    }

    /// Reads a token in the form [`encode`](Self::encode) gives, or returns None.
    pub fn decode(text: &str) -> Option<Self> {
        let mut bytes = SecretBox::<[u8; 32]>::default();
        let length = URL_SAFE_NO_PAD
            .decode_slice(text, bytes.expose_secret_mut())
            .ok()?;
        (length == bytes.expose_secret().len()).then_some(Self(bytes))
    }

    /// Returns the token as text that fits in a cookie or a header.
    pub fn encode(&self) -> String {
        URL_SAFE_NO_PAD.encode(self.0.expose_secret())
    }

    fn hash(&self) -> [u8; 32] {
        Sha256::digest(self.0.expose_secret()).into()
    }
}

/// Signs the User in on a new device, and returns them with their session token.
///
/// Returns None if the username or password is wrong.
pub async fn sign_in(
    db: &PgPool,
    username: &str,
    password: SecretString,
) -> Result<Option<(User, SessionToken)>, InternalError> {
    let Some(row) = sqlx::query!(
        r#"
        SELECT id, username, locale, is_instance_administrator, password_hash
        FROM users
        WHERE username = $1
        "#,
        username.trim(),
    )
    .fetch_optional(db)
    .await
    .context("failed to find the User signing in")?
    else {
        // Hashes the password all the same, which takes as long as checking it, so the time to
        // answer doesn't tell which usernames exist
        hash_slowly(move || password_auth::generate_hash(password.expose_secret())).await;
        return Ok(None);
    };

    let hash = row.password_hash;
    let password_matches = hash_slowly(move || {
        password_auth::verify_password(password.expose_secret(), &hash).is_ok()
    })
    .await;
    if !password_matches {
        return Ok(None);
    }

    let user = User {
        id: row.id,
        username: row.username,
        locale: row.locale,
        is_instance_administrator: row.is_instance_administrator,
    };
    let token = create_session(db, user.id).await?;
    Ok(Some((user, token)))
}

/// Returns the User the token keeps signed in, or None once their session ended or expired.
pub async fn session_user(
    db: &PgPool,
    token: &SessionToken,
) -> Result<Option<User>, InternalError> {
    let user = sqlx::query_as!(
        User,
        r#"
        SELECT u.id, u.username, u.locale, u.is_instance_administrator
        FROM sessions s
        JOIN users u ON u.id = s.user_id
        WHERE s.token_hash = $1 AND s.expires_at > now()
        "#,
        &token.hash(),
    )
    .fetch_optional(db)
    .await
    .context("failed to find the session's User")?;
    Ok(user)
}

/// Signs out the device that the token keeps signed in.
pub async fn sign_out(db: &PgPool, token: &SessionToken) -> Result<(), InternalError> {
    sqlx::query!("DELETE FROM sessions WHERE token_hash = $1", &token.hash())
        .execute(db)
        .await
        .context("failed to end a session")?;
    Ok(())
}

/// Deletes the sessions whose lifetime has run out, and returns how many it deleted.
pub async fn delete_expired_sessions(db: &PgPool) -> Result<u64, InternalError> {
    let deleted = sqlx::query!("DELETE FROM sessions WHERE expires_at < now()")
        .execute(db)
        .await
        .context("failed to delete the expired sessions")?;
    Ok(deleted.rows_affected())
}

/// Creates a session that keeps the User signed in on a new device for `SESSION_LIFETIME`, and
/// returns its token.
async fn create_session(
    db: impl PgExecutor<'_>,
    user: UserId,
) -> Result<SessionToken, InternalError> {
    let token = SessionToken::random().context("failed to generate a session token")?;
    // The database's clock, which `session_user` checks the expiry against
    sqlx::query!(
        r#"
        INSERT INTO sessions (token_hash, user_id, expires_at)
        VALUES ($1, $2, now() + make_interval(secs => $3))
        "#,
        &token.hash(),
        user as UserId,
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
    let slot = HASHING
        .acquire()
        .await
        .expect("the semaphore is never closed");
    tokio::task::spawn_blocking(move || {
        // Held until the work ends, even when the request is dropped before
        let _slot = slot;
        work()
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
