//! The Instance Administrator: the single User who administers the Instance, whom its first visitor
//! creates in Setup.

use anyhow::Context;
use sqlx_otel::QueryAnnotateExt;
use tracing::Level;

use super::{
    preferences::Locale,
    sessions::{self, SessionToken},
    users::{self, CurrentUser, Password, Username},
};
use crate::db::Pool;

/// Returns `true` once Setup has created the Instance Administrator.
#[tracing::instrument(skip_all)]
pub async fn exists(db: &Pool) -> anyhow::Result<bool> {
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

/// Creates the Instance Administrator, with a new User's preferences for their Locale, signs them in
/// on a new device and returns them as the current User.
#[tracing::instrument(skip_all)]
pub async fn create(
    db: &Pool,
    username: Username,
    password: Password,
    locale: Locale,
) -> Result<(CurrentUser, SessionToken), CreateInstanceAdministratorError> {
    let password_hash = password.hash().await;

    let mut transaction = db.begin().await.context("failed to start a transaction")?;
    let inserted = users::insert(&mut transaction, &username, password_hash, locale, true).await;
    let admin = match inserted {
        Ok(admin) => admin,
        // Users only exist once Setup created the Instance Administrator, so another one, or a
        // User with the same username, means Setup already ran
        Err(sqlx::Error::Database(error)) if error.is_unique_violation() => {
            tracing::event!(
                name: "accounts.instance_administrator.refused",
                Level::WARN,
                user.name = username.as_str(),
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
    let token = sessions::create(&mut transaction, admin.id).await?;
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
