//! The job that deletes expired sessions, every week.

use serde::{Deserialize, Serialize};
use tracing::Level;

use crate::{
    db::Pool,
    domain::accounts,
    jobs::{Job, JobError},
};

/// The cleanup of the sessions whose lifetime has run out, which would otherwise pile up.
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct DeleteExpiredSessions {}

impl Job for DeleteExpiredSessions {
    const KIND: &'static str = "delete_expired_sessions";
    // Every Sunday at 03:00
    const SCHEDULE: Option<&'static str> = Some("0 3 * * SUN");

    async fn run(self, db: &Pool) -> Result<(), JobError> {
        let deleted = accounts::delete_expired_sessions(db).await?;
        tracing::event!(
            name: "accounts.sessions.deleted",
            Level::INFO,
            deleted,
            "deleted the expired sessions",
        );
        Ok(())
    }
}
