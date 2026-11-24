//! The job that imports the Sources' new and Unmatched files, every hour.

use serde::{Deserialize, Serialize};

use crate::{
    domain::media_imports,
    jobs::{Job, JobContext, JobError},
};

/// The hourly import of every Source that imports, which keeps the Library up to date.
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct ImportSources {}

impl Job for ImportSources {
    const KIND: &'static str = "import_sources";
    // Every hour, on the hour
    const SCHEDULE: Option<&'static str> = Some("0 * * * *");

    async fn run(self, context: &JobContext) -> Result<(), JobError> {
        media_imports::start_scheduled(&context.db).await?;
        Ok(())
    }
}
