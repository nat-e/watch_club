//! The job that deletes expired sessions, every week.

use serde::{Deserialize, Serialize};
use sqlx::PgPool;

use crate::{
    domain::accounts,
    jobs::{Job, JobError},
};

/// The cleanup of the sessions whose lifetime has run out, which would otherwise pile up.
#[derive(Debug, Serialize, Deserialize)]
pub struct DeleteExpiredSessions {}

impl Job for DeleteExpiredSessions {
    async fn run(self, db: &PgPool) -> Result<(), JobError> {
        let deleted = accounts::delete_expired_sessions(db).await?;
        tracing::info!(
            name: "accounts.sessions.deleted",
            deleted,
            "deleted the expired sessions",
        );
        Ok(())
    }
}
