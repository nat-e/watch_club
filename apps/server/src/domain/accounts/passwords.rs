//! Changing passwords: Users change theirs in Settings, and a User who forgot theirs chooses a new
//! one with a Password Reset Link, which the Instance Administrator shares.
//!
//! Rare races are accepted rather than prevented with row locks: a device that signs in with the
//! old password while it changes, in the moment the server checks it, keeps its session, and a
//! change and a reset of the same password at the same instant can fail.

use anyhow::Context;
use jiff::SignedDuration;
use secrecy::SecretString;
use sqlx_otel::QueryAnnotateExt;
use tracing::Level;

use super::{Password, SessionToken, UserId, token::SecretToken, user::password_matches};
use crate::{db::Pool, domain::InternalError};

/// The time a Password Reset Link works for, from its creation.
const PASSWORD_RESET_LINK_LIFETIME: SignedDuration = SignedDuration::from_hours(24 * 3);

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
    UserNotFound,
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
            return Err(CreatePasswordResetLinkError::UserNotFound);
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
pub async fn password_reset_username(
    db: &Pool,
    token: &str,
) -> Result<Option<String>, InternalError> {
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
