//! The job that saves a Content again from its Metadata Provider, which a view queues once a day
//! has passed since it was saved.

use serde::{Deserialize, Serialize};

use crate::{
    domain::contents::{self, ContentId},
    jobs::{Job, JobContext, JobError},
};

/// The refresh of a Content's metadata, so that its next views show what changed.
#[derive(Debug, Serialize, Deserialize)]
pub struct RefreshContent {
    pub content_id: ContentId,
}

impl Job for RefreshContent {
    const KIND: &'static str = "refresh_content";

    async fn run(self, context: &JobContext) -> Result<(), JobError> {
        // On the heap: fetching a TV Show's seasons makes a large future, which would make every
        // job's as large
        Box::pin(contents::refresh(
            &context.db,
            &context.metadata_providers,
            self.content_id,
        ))
        .await?;
        Ok(())
    }
}
