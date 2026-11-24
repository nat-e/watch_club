//! The job that runs a Media Import, which the Instance Administrator or the hourly schedule
//! started.

use std::time::Duration;

use serde::{Deserialize, Serialize};

use crate::{
    domain::media_imports::{self, MediaImportId},
    jobs::{Job, JobContext, JobError},
};

/// A Media Import to run, which brings its Source's Media Files in.
#[derive(Debug, Serialize, Deserialize)]
pub struct ImportMedia {
    pub media_import_id: MediaImportId,
}

impl Job for ImportMedia {
    const KIND: &'static str = "import_media";
    // Once: a retry would count the files of the failed attempt again. The import saves how it
    // failed, and the next hourly import goes on from where it stopped
    const MAX_ATTEMPTS: i16 = 1;
    // The most the runner allows, for the first import of a large library, which saves each of its
    // Movies from TMDB
    const TIMEOUT: Duration = Duration::from_mins(59);

    async fn run(self, context: &JobContext) -> Result<(), JobError> {
        // On the heap: saving Contents makes a large future, which would make every job's as large
        Box::pin(media_imports::run(
            &context.db,
            &context.metadata_providers,
            &context.http_client,
            &context.encryption_key,
            self.media_import_id,
        ))
        .await?;
        Ok(())
    }
}
