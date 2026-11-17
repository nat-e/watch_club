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
mod runner;
mod schedules;

use std::time::Duration;

use anyhow::Context;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{PgExecutor, PgPool};
use uuid::Uuid;

use self::runner::RESCUE_AFTER;
#[cfg(feature = "test-util")]
pub use self::runner::run_available;
pub use self::{kinds::delete_expired_sessions::DeleteExpiredSessions, runner::run};
use crate::domain::InternalError;

/// Work that runs in the background: a struct with the job's arguments, which also sets its
/// settings.
pub trait Job {
    /// The queue the job runs in.
    const QUEUE: Queue = Queue::Default;
    /// The job's place in its queue, from 0, which runs first, to 9.
    const PRIORITY: i16 = 0;
    /// The number of times the job starts before it fails for good.
    const MAX_ATTEMPTS: i16 = 3;
    /// The time an attempt may take, after which it stops and counts as failed.
    ///
    /// It must be shorter than an hour, after which a job that's still running counts as crashed
    /// and runs again: the `check_timeout` line below `AnyJob` checks it. The timeout only stops a
    /// job at an `.await`, so blocking work, such as `spawn_blocking` or a child process, needs its
    /// own limit.
    const TIMEOUT: Duration = Duration::from_mins(10);

    /// The cron expression, in UTC, on which the server queues this job by itself with its default
    /// arguments, such as `0 3 * * SUN`. None for a job that only runs when something queues it.
    const SCHEDULE: Option<&'static str> = None;

    /// Does the job's work.
    fn run(self, db: &PgPool) -> impl Future<Output = Result<(), JobError>> + Send;
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

/// Every job, stored as its `kind` and its `args`. Each kind is spelled out, so that renaming a
/// type doesn't change what's stored.
#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "kind", content = "args")]
pub enum AnyJob {
    #[serde(rename = "delete_expired_sessions")]
    DeleteExpiredSessions(DeleteExpiredSessions),
}

const _: () = check_timeout(DeleteExpiredSessions::TIMEOUT);

impl From<DeleteExpiredSessions> for AnyJob {
    fn from(job: DeleteExpiredSessions) -> Self {
        Self::DeleteExpiredSessions(job)
    }
}

impl AnyJob {
    fn settings(&self) -> Settings {
        match self {
            Self::DeleteExpiredSessions(_) => Settings::of::<DeleteExpiredSessions>(),
        }
    }

    async fn run(self, db: &PgPool) -> Result<(), JobError> {
        match self {
            Self::DeleteExpiredSessions(job) => job.run(db).await,
        }
    }

    /// Returns the cron expression and job of each kind with a `SCHEDULE`. List each such kind
    /// here.
    fn schedules() -> impl Iterator<Item = (&'static str, Self)> {
        [scheduled::<DeleteExpiredSessions>()].into_iter().flatten()
    }

    /// Reads a job from its stored kind and arguments.
    fn from_row(kind: &str, args: Value) -> serde_json::Result<Self> {
        serde_json::from_value(Value::from_iter([
            ("kind", Value::from(kind)),
            ("args", args),
        ]))
    }

    /// Returns the job's kind and arguments, as the database stores them.
    fn to_row(&self) -> anyhow::Result<(String, Value)> {
        let mut stored = serde_json::to_value(self).context("failed to serialize a job")?;
        let kind = stored["kind"].take();
        let kind = kind.as_str().expect("serde tags every job with its kind");
        Ok((kind.to_owned(), stored["args"].take()))
    }
}

/// Returns the cron expression of the kind's `SCHEDULE`, with a job of that kind to queue on it.
fn scheduled<J: Job + Default + Into<AnyJob>>() -> Option<(&'static str, AnyJob)> {
    J::SCHEDULE.map(|cron| (cron, J::default().into()))
}

/// The settings of a job, from its `Job` implementation.
struct Settings {
    queue: Queue,
    priority: i16,
    max_attempts: i16,
    timeout: Duration,
}

impl Settings {
    const fn of<J: Job>() -> Self {
        Self {
            queue: J::QUEUE,
            priority: J::PRIORITY,
            max_attempts: J::MAX_ATTEMPTS,
            timeout: J::TIMEOUT,
        }
    }
}

/// Fails `cargo check` when a job's timeout isn't shorter than `RESCUE_AFTER`: the job would run
/// again while it's still running.
const fn check_timeout(timeout: Duration) {
    assert!(
        timeout.as_nanos() < RESCUE_AFTER.as_nanos(),
        "a job's TIMEOUT must be shorter than RESCUE_AFTER"
    );
}

/// Queues the job to run as soon as its queue has room. In a transaction, the job is only queued
/// if the transaction commits.
pub async fn enqueue(
    db: impl PgExecutor<'_>,
    job: impl Into<AnyJob>,
) -> Result<JobId, InternalError> {
    let job = job.into();
    let settings = job.settings();
    let (kind, args) = job.to_row()?;
    let id = sqlx::query_scalar!(
        r#"
        INSERT INTO jobs (queue, kind, args, priority, max_attempts)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id
        "#,
        settings.queue as Queue,
        kind,
        args,
        settings.priority,
        settings.max_attempts,
    )
    .fetch_one(db)
    .await
    .with_context(|| format!("failed to queue a {kind} job"))?;
    Ok(id)
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
