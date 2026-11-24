//! The job that deletes the old Media Imports, every week.

use serde::{Deserialize, Serialize};
use tracing::Level;

use crate::{
    domain::media_imports,
    jobs::{Job, JobContext, JobError},
};

/// The cleanup of the Media Imports that finished over 30 days ago, which the hourly imports would
/// otherwise pile up.
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct DeleteOldMediaImports {}

impl Job for DeleteOldMediaImports {
    const KIND: &'static str = "delete_old_media_imports";
    // Every Sunday at 03:00
    const SCHEDULE: Option<&'static str> = Some("0 3 * * SUN");

    async fn run(self, context: &JobContext) -> Result<(), JobError> {
        let deleted = media_imports::delete_old(&context.db).await?;
        tracing::event!(
            name: "media_imports.deleted",
            Level::INFO,
            deleted,
            "deleted the old Media Imports",
        );
        Ok(())
    }
}
