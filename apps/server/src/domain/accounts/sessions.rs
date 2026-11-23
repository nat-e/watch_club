//! Sessions: what keeps a User signed in on a device, from signing in until they sign out or it
//! expires.

use anyhow::Context;
use jiff::SignedDuration;
use secrecy::SecretString;
use sqlx::PgExecutor;
use sqlx_otel::QueryAnnotateExt;
use tracing::Level;

use super::{
    token::SecretToken,
    users::{self, CurrentUser, UserId, UserRow},
};
use crate::db::Pool;

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

/// The reason a User wasn't signed in.
#[derive(Debug, thiserror::Error)]
pub enum SignInError {
    /// No User has the username, or the password isn't theirs
    #[error("wrong username or password")]
    WrongCredentials,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Signs the User in on a new device, and returns them with their session token.
#[tracing::instrument(skip_all)]
pub async fn sign_in(
    db: &Pool,
    username: &str,
    password: SecretString,
) -> Result<(CurrentUser, SessionToken), SignInError> {
    let username = username.trim();
    let Some(user) = users::check_credentials(db, username, password).await? else {
        tracing::event!(
            name: "accounts.sign_in.failed",
            Level::WARN,
            user.name = username,
            "wrong username or password",
        );
        return Err(SignInError::WrongCredentials);
    };
    let token = create(db, user.id).await?;
    tracing::event!(
        name: "accounts.sign_in.succeeded",
        Level::INFO,
        user.id = %user.id,
        user.name = user.username,
        "signed in",
    );
    Ok((user, token))
}

/// Returns the User the token keeps signed in, or None once their session ended or expired.
#[tracing::instrument(skip_all)]
pub async fn get_current_user(
    db: &Pool,
    token: &SessionToken,
) -> anyhow::Result<Option<CurrentUser>> {
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
pub async fn sign_out(db: &Pool, token: &SessionToken) -> anyhow::Result<()> {
    sqlx::query!("DELETE FROM sessions WHERE token_hash = $1", &token.hash())
        .with_operation("DELETE", "sessions")
        .execute(db)
        .await
        .context("failed to end a session")?;
    Ok(())
}

/// Deletes the sessions whose lifetime has run out, and returns how many it deleted.
#[tracing::instrument(skip_all)]
pub async fn delete_expired(db: &Pool) -> anyhow::Result<u64> {
    let deleted = sqlx::query!("DELETE FROM sessions WHERE expires_at < now()")
        .with_operation("DELETE", "sessions")
        .execute(db)
        .await
        .context("failed to delete the expired sessions")?;
    Ok(deleted.rows_affected())
}

/// Creates a session that keeps the User signed in on a new device for `SESSION_LIFETIME`, and
/// returns its token.
pub(super) async fn create(
    db: impl PgExecutor<'_>,
    user_id: UserId,
) -> anyhow::Result<SessionToken> {
    let token = SecretToken::random()
        .map(SessionToken)
        .context("failed to generate a session token")?;
    // The database's clock, which `get_current_user` checks the expiry against
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
