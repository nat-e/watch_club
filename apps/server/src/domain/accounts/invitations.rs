//! Invitations: the links the Instance Administrator shares so that new people can create their
//! account.

use std::{fmt, num::NonZeroU32};

use anyhow::Context;
use jiff::{SignedDuration, Timestamp};
use serde::{Deserialize, Serialize};
use sqlx_otel::QueryAnnotateExt;
use tracing::Level;
use utoipa::ToSchema;
use uuid::Uuid;

use super::{
    CurrentUser, Locale, Password, SessionToken, Username,
    user::{CreateUserError, create_user},
};
use crate::{db::Pool, domain::InternalError};

/// The unique ID of an Invitation.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[sqlx(transparent)]
pub struct InvitationId(Uuid);

impl fmt::Display for InvitationId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(f)
    }
}

/// The time an Invitation works for, from its creation.
const INVITATION_LIFETIME: SignedDuration = SignedDuration::from_hours(24 * 7);

/// A link that lets new people create their account, until it expires or reaches its Max Uses.
#[derive(Clone, PartialEq, Eq, Serialize, ToSchema)]
pub struct Invitation {
    pub id: InvitationId,
    /// The code in the link
    pub code: String,
    /// The most Users it can create, or null for no limit
    #[schema(minimum = 1, required = true)]
    pub max_uses: Option<i64>,
    /// The Users it created
    pub uses: i64,
    /// When it stops working
    #[schema(value_type = String, format = DateTime)]
    pub expires_at: Timestamp,
}

/// Leaves the code out, which lets anyone create an account.
impl fmt::Debug for Invitation {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Invitation")
            .field("id", &self.id)
            .field("max_uses", &self.max_uses)
            .field("uses", &self.uses)
            .field("expires_at", &self.expires_at)
            .finish_non_exhaustive()
    }
}

/// An Invitation as `invitations` stores it.
struct InvitationRow {
    id: InvitationId,
    code: String,
    max_uses: Option<i64>,
    uses: i64,
    expires_at: jiff_sqlx::Timestamp,
}

impl From<InvitationRow> for Invitation {
    fn from(row: InvitationRow) -> Self {
        Self {
            id: row.id,
            code: row.code,
            max_uses: row.max_uses,
            uses: row.uses,
            expires_at: row.expires_at.to_jiff(),
        }
    }
}

/// Returns the Invitations that can still be redeemed, the oldest first.
#[tracing::instrument(skip_all)]
pub async fn list_redeemable_invitations(db: &Pool) -> Result<Vec<Invitation>, InternalError> {
    // Every Invitation works for as long, so the first to expire is the oldest
    let rows = sqlx::query_as!(
        InvitationRow,
        r#"
        SELECT id, code, max_uses, uses, expires_at
        FROM invitations
        WHERE expires_at > now() AND (max_uses IS NULL OR uses < max_uses)
        ORDER BY expires_at
        "#
    )
    .with_operation("SELECT", "invitations")
    .fetch_all(db)
    .await
    .context("failed to list the Invitations")?;
    Ok(rows.into_iter().map(Invitation::from).collect())
}

/// Creates an Invitation with a random code, which works for `INVITATION_LIFETIME`.
#[tracing::instrument(skip_all)]
pub async fn create_invitation(
    db: &Pool,
    max_uses: Option<NonZeroU32>,
) -> Result<Invitation, InternalError> {
    let code = random_code().context("failed to generate an Invitation's code")?;
    // The database's clock, which redeeming checks the expiry against
    let row = sqlx::query_as!(
        InvitationRow,
        r#"
        INSERT INTO invitations (code, max_uses, expires_at)
        VALUES ($1, $2, now() + make_interval(secs => $3))
        RETURNING id, code, max_uses, uses, expires_at
        "#,
        code,
        max_uses.map(|max_uses| i64::from(max_uses.get())),
        INVITATION_LIFETIME.as_secs_f64(),
    )
    .with_operation("INSERT", "invitations")
    .fetch_one(db)
    .await
    .context("failed to create an Invitation")?;
    Ok(row.into())
}

/// The reason an Invitation's Max Uses didn't change.
#[derive(Debug, thiserror::Error)]
pub enum ChangeMaxUsesError {
    #[error("no such Invitation")]
    NotFound,
    /// The Invitation has created more Users already
    #[error("the Max Uses is lower than the Invitation's uses")]
    BelowUses,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Changes the most Users the Invitation can create, or removes the limit, and returns the
/// Invitation.
#[tracing::instrument(skip_all, fields(invitation.id = %invitation))]
pub async fn change_max_uses(
    db: &Pool,
    invitation: InvitationId,
    max_uses: Option<NonZeroU32>,
) -> Result<Invitation, ChangeMaxUsesError> {
    let changed = sqlx::query_as!(
        InvitationRow,
        r#"
        UPDATE invitations
        SET max_uses = $2
        WHERE id = $1
        RETURNING id, code, max_uses, uses, expires_at
        "#,
        invitation as InvitationId,
        max_uses.map(|max_uses| i64::from(max_uses.get())),
    )
    .with_operation("UPDATE", "invitations")
    .fetch_optional(db)
    .await;
    match changed {
        Ok(Some(row)) => Ok(row.into()),
        Ok(None) => Err(ChangeMaxUsesError::NotFound),
        // The constraint that keeps the uses within the Max Uses, the only one an update can break
        Err(sqlx::Error::Database(error)) if error.is_check_violation() => {
            Err(ChangeMaxUsesError::BelowUses)
        }
        Err(error) => Err(anyhow::Error::new(error)
            .context("failed to change an Invitation's Max Uses")
            .into()),
    }
}

/// Deletes the Invitation, so that nobody can redeem it anymore. The Users it created stay.
/// Succeeds when there's no such Invitation, such as when it's deleted already.
#[tracing::instrument(skip_all, fields(invitation.id = %invitation))]
pub async fn delete_invitation(db: &Pool, invitation: InvitationId) -> Result<(), InternalError> {
    sqlx::query!(
        "DELETE FROM invitations WHERE id = $1",
        invitation as InvitationId,
    )
    .with_operation("DELETE", "invitations")
    .execute(db)
    .await
    .context("failed to delete an Invitation")?;
    Ok(())
}

/// Returns whether the code is an Invitation's that can still be redeemed.
#[tracing::instrument(skip_all)]
pub async fn is_redeemable(db: &Pool, code: &str) -> Result<bool, InternalError> {
    let is_redeemable = sqlx::query_scalar!(
        r#"
        SELECT EXISTS (
            SELECT FROM invitations
            WHERE code = $1 AND expires_at > now() AND (max_uses IS NULL OR uses < max_uses)
        ) AS "exists!"
        "#,
        code,
    )
    .with_operation("SELECT", "invitations")
    .fetch_one(db)
    .await
    .context("failed to check an Invitation")?;
    Ok(is_redeemable)
}

/// The reason an Invitation wasn't redeemed.
#[derive(Debug, thiserror::Error)]
pub enum RedeemInvitationError {
    /// No Invitation has the code, or it expired or reached its Max Uses
    #[error("the Invitation can't be redeemed")]
    NotRedeemable,
    #[error("another User has the username")]
    UsernameTaken,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

impl From<InternalError> for RedeemInvitationError {
    fn from(error: InternalError) -> Self {
        Self::Internal(error.0)
    }
}

/// Creates a User with the Invitation's code, with a new User's preferences for their Locale, signs
/// them in on a new device and returns them as the current User. The Invitation counts one more use.
#[tracing::instrument(skip_all)]
pub async fn redeem_invitation(
    db: &Pool,
    code: &str,
    username: Username,
    password: Password,
    locale: Locale,
) -> Result<(CurrentUser, SessionToken), RedeemInvitationError> {
    let password_hash = password.hash().await;

    let mut transaction = db.begin().await.context("failed to start a transaction")?;
    // Locks the Invitation until the transaction ends, so that people who redeem it at once don't
    // exceed its Max Uses. Creating the User fails after it when the username is taken, which
    // gives the use back
    let invitation = sqlx::query_scalar!(
        r#"
        UPDATE invitations
        SET uses = uses + 1
        WHERE code = $1 AND expires_at > now() AND (max_uses IS NULL OR uses < max_uses)
        RETURNING id
        "#,
        code,
    )
    .with_operation("UPDATE", "invitations")
    .fetch_optional(&mut transaction)
    .await
    .context("failed to use an Invitation")?;
    let Some(invitation) = invitation else {
        return Err(RedeemInvitationError::NotRedeemable);
    };

    let (user, token) =
        match create_user(&mut transaction, &username, password_hash, locale, false).await {
            Ok(created) => created,
            Err(CreateUserError::NotUnique) => return Err(RedeemInvitationError::UsernameTaken),
            Err(CreateUserError::Internal(error)) => return Err(error.into()),
        };
    transaction
        .commit()
        .await
        .context("failed to redeem an Invitation")?;
    tracing::event!(
        name: "accounts.invitation.redeemed",
        Level::INFO,
        invitation.id = %invitation,
        user.id = %user.id,
        user.name = user.username,
        "created a User with an Invitation",
    );
    Ok((user, token))
}

/// Returns a random code of 16 uppercase letters and digits: 80 bits, which nobody can guess.
fn random_code() -> Result<String, getrandom::Error> {
    // 32 characters, so each comes from 5 bits of a random byte, all as likely. Without 0, O, 1
    // and I, which look alike
    const ALPHABET: &[u8; 32] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let mut bytes = [0_u8; 16];
    getrandom::fill(&mut bytes)?;
    let code = bytes
        .iter()
        .map(|byte| char::from(ALPHABET[usize::from(byte % 32)]))
        .collect();
    Ok(code)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn debug_hides_the_code() {
        let invitation = Invitation {
            id: InvitationId(Uuid::nil()),
            code: "SECRETCODE234567".to_owned(),
            max_uses: None,
            uses: 0,
            expires_at: Timestamp::UNIX_EPOCH,
        };

        assert!(!format!("{invitation:?}").contains("SECRETCODE234567"));
    }

    #[test]
    fn random_codes_are_16_unambiguous_characters() {
        let code = random_code().unwrap();

        assert_eq!(code.len(), 16);
        assert!(
            code.chars()
                .all(|c| "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains(c))
        );
        assert_ne!(code, random_code().unwrap());
    }
}
