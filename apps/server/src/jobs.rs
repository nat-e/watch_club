//! Background jobs: work the server runs outside requests, from a queue in the database.
//!
//! Each kind of job has its file in `jobs/kinds/`, apart from the runner's code: a struct with its
//! arguments, whose `Job` implementation sets its settings, its schedule if it recurs, and calls a
//! function of the domain. List it in `AnyJob` and the lines below it.
//!
//! A job runs at least once: a crash can make it run again, so every job must be safe to repeat.
//! The database stores its arguments as JSON until it runs, so change them in ways that still read
//! the stored ones, such as adding an `Option` field, or rewrite the queued jobs in a migration.
//! Pass IDs rather than whole records.

// The kinds of jobs, one per file
mod kinds {
    pub(super) mod delete_expired_sessions;
}
mod observability;
mod runner;
mod schedules;

use std::{collections::BTreeMap, time::Duration};

use anyhow::{Context, bail};
use serde::{Serialize, de::DeserializeOwned};
use serde_json::Value;
use sqlx::PgExecutor;
use uuid::Uuid;

pub use self::{
    kinds::delete_expired_sessions::DeleteExpiredSessions,
    runner::{run, run_available},
};
use crate::{db::Pool, domain::InternalError};

/// Work that runs in the background: a struct with the job's arguments, which also sets its
/// settings.
pub trait Job: Serialize + DeserializeOwned {
    /// The name the database stores this kind of job under. Queued jobs keep it, so never change
    /// it.
    const KIND: &'static str;
    /// The queue the job runs in.
    const QUEUE: Queue = Queue::Default;
    /// The job's place in its queue, from 0, which runs first, to 9.
    const PRIORITY: i16 = 0;
    /// The number of times the job starts before it fails for good.
    const MAX_ATTEMPTS: i16 = 3;
    /// The time an attempt may take, after which it stops and counts as failed.
    ///
    /// The runner stops an attempt after 59 minutes at most, since a job still running after an
    /// hour counts as crashed and runs again. The timeout only stops a job at an `.await`, so
    /// blocking work, such as `spawn_blocking` or a child process, needs its own limit.
    const TIMEOUT: Duration = Duration::from_mins(10);
    /// The cron expression, in UTC, on which the server queues this job by itself with its default
    /// arguments, such as `0 3 * * SUN`. None for a job that only runs when something queues it.
    const SCHEDULE: Option<&'static str> = None;

    /// Does the job's work.
    fn run(self, db: &Pool) -> impl Future<Output = Result<(), JobError>> + Send;
}

/// The reason a job didn't complete. A job with nothing left to do, such as when what it works on
/// is gone, completes instead.
#[derive(Debug, thiserror::Error)]
pub enum JobError {
    /// A failure that may go away, such as the database being down. The job runs again later,
    /// unless it has no attempts left.
    #[error(transparent)]
    Retryable(#[from] anyhow::Error),
    /// A failure that trying again won't fix, such as invalid arguments. The job ends failed at
    /// once.
    #[error(transparent)]
    NonRetryable(anyhow::Error),
}

impl From<InternalError> for JobError {
    fn from(error: InternalError) -> Self {
        Self::Retryable(error.into())
    }
}

/// A queue of jobs, which runs up to its limit of them at once.
#[derive(Clone, Copy, Debug, PartialEq, Eq, sqlx::Type)]
#[sqlx(type_name = "text", rename_all = "snake_case")]
pub enum Queue {
    Default,
}

impl Queue {
    const ALL: [Self; 1] = [Self::Default];

    /// Returns the number of the queue's jobs that run at once.
    const fn limit(self) -> usize {
        match self {
            Self::Default => 10,
        }
    }

    /// Returns the queue's name, as the database stores it.
    const fn name(self) -> &'static str {
        match self {
            Self::Default => "default",
        }
    }
}

/// The state of a job.
#[derive(Clone, Copy, Debug, PartialEq, Eq, sqlx::Type)]
#[sqlx(type_name = "job_state", rename_all = "snake_case")]
pub enum JobState {
    /// Waiting in its queue until its time comes, for its first attempt or a retry
    Available,
    Executing,
    Completed,
    /// Failed for good
    Failed,
    /// Cancelled with `cancel` before it ran
    Cancelled,
}

/// The unique ID of a job.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, sqlx::Type)]
#[sqlx(transparent)]
pub struct JobId(Uuid);

/// Every kind of job, to run a stored one.
#[derive(Debug)]
enum AnyJob {
    DeleteExpiredSessions(DeleteExpiredSessions),
}

impl AnyJob {
    /// Reads a stored job from its kind and arguments.
    fn from_row(kind: &str, args: Value) -> anyhow::Result<Self> {
        Ok(match kind {
            DeleteExpiredSessions::KIND => {
                Self::DeleteExpiredSessions(serde_json::from_value(args)?)
            }
            _ => bail!("unknown kind of job: {kind}"),
        })
    }

    fn timeout(&self) -> Duration {
        match self {
            Self::DeleteExpiredSessions(_) => DeleteExpiredSessions::TIMEOUT,
        }
    }

    async fn run(self, db: &Pool) -> Result<(), JobError> {
        match self {
            Self::DeleteExpiredSessions(job) => job.run(db).await,
        }
    }
}

/// Returns the cron expression of each kind with a `SCHEDULE`, with the job to queue on it, by
/// kind. List each such kind here.
fn schedules() -> serde_json::Result<BTreeMap<&'static str, (&'static str, NewJob)>> {
    [scheduled::<DeleteExpiredSessions>()]
        .into_iter()
        .flatten()
        .collect()
}

fn scheduled<J: Job + Default>()
-> Option<serde_json::Result<(&'static str, (&'static str, NewJob))>> {
    let cron = J::SCHEDULE?;
    Some(NewJob::of(&J::default()).map(|job| (J::KIND, (cron, job))))
}

/// A job to insert in the queue: its kind, its arguments and its settings.
#[derive(Debug)]
struct NewJob {
    kind: &'static str,
    args: Value,
    queue: Queue,
    priority: i16,
    max_attempts: i16,
}

impl NewJob {
    fn of<J: Job>(job: &J) -> serde_json::Result<Self> {
        Ok(Self {
            kind: J::KIND,
            args: serde_json::to_value(job)?,
            queue: J::QUEUE,
            priority: J::PRIORITY,
            max_attempts: J::MAX_ATTEMPTS,
        })
    }

    async fn insert(self, db: impl PgExecutor<'_>) -> Result<JobId, InternalError> {
        let id = sqlx::query_scalar!(
            r#"
            INSERT INTO jobs (queue, kind, args, priority, max_attempts)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id
            "#,
            self.queue as Queue,
            self.kind,
            self.args,
            self.priority,
            self.max_attempts,
        )
        .fetch_one(db)
        .await
        .with_context(|| format!("failed to queue a {} job", self.kind))?;
        Ok(id)
    }
}

/// A job the runner claimed, which is `executing` from then on.
struct ClaimedJob {
    id: JobId,
    kind: String,
    queue: Queue,
    args: Value,
    attempt: i16,
    max_attempts: i16,
}

/// Queues the job to run as soon as its queue has room. In a transaction, the job is only queued
/// if the transaction commits.
pub async fn enqueue<J: Job>(db: impl PgExecutor<'_>, job: J) -> Result<JobId, InternalError> {
    let new_job = NewJob::of(&job).context("failed to serialize a job")?;
    new_job.insert(db).await
}

/// Cancels the job if it's waiting in its queue, for its first attempt or a retry, and returns
/// whether it did. A running job goes on, and a finished or missing job stays as it is.
pub async fn cancel(db: impl PgExecutor<'_>, id: JobId) -> Result<bool, InternalError> {
    let cancelled = sqlx::query!(
        r#"
        UPDATE jobs SET state = 'cancelled', finished_at = now()
        WHERE id = $1 AND state = 'available'
        "#,
        id as JobId,
    )
    .execute(db)
    .await
    .context("failed to cancel a job")?;
    Ok(cancelled.rows_affected() == 1)
}
