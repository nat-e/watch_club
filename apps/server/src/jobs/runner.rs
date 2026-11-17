//! The runner, which runs the queued jobs inside the server: each queue's jobs in parallel up to
//! its limit, with retries, and the maintenance that queues the scheduled jobs, rescues the jobs a
//! crash left running and deletes old ones.

use std::{
    any::Any,
    panic::{self, AssertUnwindSafe},
    time::Duration,
};

use anyhow::{Context, anyhow};
use futures_util::{FutureExt, future};
use serde_json::Value;
use sqlx::PgPool;
use tokio::{
    task::{JoinError, JoinSet},
    time::{self, MissedTickBehavior},
};
use tokio_util::sync::CancellationToken;
use tracing::Instrument;

use super::{AnyJob, JobError, JobId, JobState, Queue, schedules};
use crate::domain::InternalError;

/// The time after which a job still `executing` counts as left behind by a crash, or by a shutdown
/// that didn't wait for it, and runs again. Every job's timeout is shorter.
pub(super) const RESCUE_AFTER: Duration = Duration::from_hours(1);

/// The time an idle queue waits before it looks for due jobs again.
const POLL_INTERVAL: Duration = Duration::from_secs(1);

/// The time between two rounds of maintenance, which is as late as a scheduled job can be queued.
const MAINTENANCE_INTERVAL: Duration = Duration::from_mins(1);

/// The time finished jobs are kept, to look into what happened.
const KEEP_FINISHED: Duration = Duration::from_hours(7 * 24);

/// The time the runner has to stop once shutdown is requested: less than the 10 s `docker stop`
/// waits before it kills the server.
const SHUTDOWN_WAIT: Duration = Duration::from_secs(8);

/// Runs the queued jobs until `shutdown` is cancelled, then waits up to 8 s for the running ones.
/// Those still running then stay `executing` until they're rescued.
pub async fn run(db: PgPool, shutdown: CancellationToken) -> Result<(), InternalError> {
    let work = async {
        schedules::sync(&db).await?;
        let queues = future::join_all(Queue::ALL.map(|queue| run_queue(&db, queue, &shutdown)));
        tokio::join!(queues, maintain(&db, &shutdown));
        Ok(())
    };
    let deadline = async {
        shutdown.cancelled().await;
        time::sleep(SHUTDOWN_WAIT).await;
    };
    tokio::select! {
        ran = work => ran,
        // Drops the work, which stops the jobs still running
        () = deadline => {
            tracing::warn!(
                name: "jobs.shutdown.timed_out",
                "stopped the jobs still running at shutdown, which will run again later",
            );
            Ok(())
        }
    }
}

/// Does at once what the runner does over time, for tests: syncs the schedules, runs the
/// maintenance, then runs the due jobs one at a time, in the order the runner claims them, until
/// none is left.
#[cfg(feature = "test-util")]
pub async fn run_available(db: &PgPool) -> Result<(), InternalError> {
    schedules::sync(db).await?;
    run_maintenance(db).await?;
    for queue in Queue::ALL {
        while let Some(job) = claim(db, queue, 1).await?.pop() {
            run_claimed(db, job).await;
        }
    }
    Ok(())
}

/// Claims the queue's due jobs whenever it has room, and runs each in its own task, until
/// `shutdown` is cancelled. Then waits for the running jobs.
async fn run_queue(db: &PgPool, queue: Queue, shutdown: &CancellationToken) {
    let mut running = JoinSet::new();
    loop {
        while let Some(ended) = running.try_join_next() {
            propagate_panic(ended);
        }
        let room = queue.limit() - running.len();
        let claimed = if room == 0 {
            Vec::new()
        } else {
            claim(db, queue, room).await.unwrap_or_else(|error| {
                tracing::error!(
                    name: "jobs.claim.failed",
                    ?queue,
                    error = %format_args!("{error:#}"),
                    "failed to claim jobs",
                );
                Vec::new()
            })
        };
        // With room to spare, the queue has no other due job for now
        let is_drained = claimed.len() < room;
        for job in claimed {
            let db = db.clone();
            running.spawn(async move { run_claimed(&db, job).await });
        }
        tokio::select! {
            () = shutdown.cancelled() => break,
            () = time::sleep(POLL_INTERVAL), if is_drained => {}
            Some(ended) = running.join_next(), if !is_drained => propagate_panic(ended),
        }
    }
    while let Some(ended) = running.join_next().await {
        propagate_panic(ended);
    }
}

/// Panics again with the panic of a job's task. `supervise` catches the job's own panics, so this
/// one comes from the runner itself, which must stop.
fn propagate_panic(ended: Result<(), JoinError>) {
    if let Err(error) = ended
        && error.is_panic()
    {
        panic::resume_unwind(error.into_panic());
    }
}

/// A job the runner claimed, which is `executing` from then on.
struct ClaimedJob {
    id: JobId,
    kind: String,
    args: Value,
    attempt: i32,
    max_attempts: i32,
}

/// Claims up to `limit` of the queue's due jobs, by priority and then by time. No other claim gets
/// them, even from another server.
async fn claim(db: &PgPool, queue: Queue, limit: usize) -> Result<Vec<ClaimedJob>, InternalError> {
    let limit = i64::try_from(limit).expect("a queue's limit is small");
    let jobs = sqlx::query_as!(
        ClaimedJob,
        r#"
        UPDATE jobs
        SET state = 'executing', attempt = attempt + 1, attempted_at = now()
        WHERE id IN (
            SELECT id
            FROM jobs
            WHERE queue = $1 AND state = 'available' AND run_at <= now()
            ORDER BY priority, run_at, id
            LIMIT $2
            FOR UPDATE SKIP LOCKED
        )
        RETURNING id, kind, args, attempt, max_attempts
        "#,
        queue as Queue,
        limit,
    )
    .fetch_all(db)
    .await
    .context("failed to claim jobs")?;
    Ok(jobs)
}

/// Runs a claimed job, and records how its attempt ended. Arguments that don't read count as a
/// failed attempt.
async fn run_claimed(db: &PgPool, mut job: ClaimedJob) {
    let span = tracing::info_span!("job", kind = %job.kind, id = %job.id.0);
    async {
        let ended = match AnyJob::load(&job.kind, job.args.take()) {
            Ok(any_job) => {
                let timeout = any_job.settings().timeout;
                supervise(timeout, any_job.run(db)).await
            }
            Err(error) => {
                let error = anyhow::Error::new(error).context("failed to read the job's arguments");
                Err(error.into())
            }
        };
        record(db, &job, ended).await;
    }
    .instrument(span)
    .await;
}

/// Runs a job's work under its timeout, and returns how it ended. A panic or a timeout counts as a
/// failed attempt.
async fn supervise(
    timeout: Duration,
    work: impl Future<Output = Result<(), JobError>>,
) -> Result<(), JobError> {
    match time::timeout(timeout, AssertUnwindSafe(work).catch_unwind()).await {
        Ok(Ok(ended)) => ended,
        Ok(Err(panic)) => Err(anyhow!("panicked: {}", panic_message(&*panic)).into()),
        Err(_) => Err(anyhow!("timed out after {timeout:?}").into()),
    }
}

/// Returns the message of a panic, which is a `&str` or a `String` when it has one.
fn panic_message(panic: &(dyn Any + Send)) -> &str {
    panic
        .downcast_ref::<&str>()
        .copied()
        .or_else(|| panic.downcast_ref::<String>().map(String::as_str))
        .unwrap_or("no message")
}

/// Records how a job's attempt ended: completed, cancelled, failed, or back in its queue to try
/// again after a backoff.
async fn record(db: &PgPool, job: &ClaimedJob, ended: Result<(), JobError>) {
    let (attempt, max_attempts) = (job.attempt, job.max_attempts);
    let recorded = match ended {
        Ok(()) => finish(db, job, JobState::Completed).await,
        Err(JobError::Cancel(reason)) => {
            tracing::info!(name: "jobs.job.cancelled", reason, "the job cancelled itself");
            finish(db, job, JobState::Cancelled).await
        }
        Err(JobError::Fail(error)) => {
            tracing::error!(
                name: "jobs.job.failed",
                attempt,
                error = %format_args!("{error:#}"),
                "the job failed for good",
            );
            finish(db, job, JobState::Failed).await
        }
        Err(JobError::Internal(error)) if attempt < max_attempts => {
            tracing::warn!(
                name: "jobs.attempt.failed",
                attempt,
                max_attempts,
                error = %format_args!("{error:#}"),
                "the job's attempt failed, and will retry",
            );
            retry(db, job).await
        }
        Err(JobError::Internal(error)) => {
            tracing::error!(
                name: "jobs.job.failed",
                attempt,
                error = %format_args!("{error:#}"),
                "the job's last attempt failed",
            );
            finish(db, job, JobState::Failed).await
        }
    };
    if let Err(error) = recorded {
        tracing::error!(
            name: "jobs.record.failed",
            error = %format_args!("{error:#}"),
            "failed to record how the job ended",
        );
    }
}

// `finish` and `retry` leave a job alone once it's no longer this attempt's: after a rescue, it
// belongs to the next attempt.

/// Ends the job in `state`: completed, failed or cancelled.
async fn finish(db: &PgPool, job: &ClaimedJob, state: JobState) -> Result<(), InternalError> {
    sqlx::query!(
        r#"
        UPDATE jobs SET state = $3, finished_at = now()
        WHERE id = $1 AND attempt = $2 AND state = 'executing'
        "#,
        job.id as JobId,
        job.attempt,
        state as JobState,
    )
    .execute(db)
    .await
    .context("failed to finish a job")?;
    Ok(())
}

/// Puts a job back in its queue to try again after `attempt⁴ + 15` seconds, plus up to 10% at
/// random so that jobs that failed together don't retry together.
async fn retry(db: &PgPool, job: &ClaimedJob) -> Result<(), InternalError> {
    sqlx::query!(
        r#"
        UPDATE jobs
        SET state = 'available',
            run_at = now() + make_interval(secs => (power(attempt, 4) + 15) * (1 + random() / 10))
        WHERE id = $1 AND attempt = $2 AND state = 'executing'
        "#,
        job.id as JobId,
        job.attempt,
    )
    .execute(db)
    .await
    .context("failed to retry a job")?;
    Ok(())
}

/// Runs the maintenance every minute, starting now, until `shutdown` is cancelled.
async fn maintain(db: &PgPool, shutdown: &CancellationToken) {
    let mut ticks = time::interval(MAINTENANCE_INTERVAL);
    ticks.set_missed_tick_behavior(MissedTickBehavior::Delay);
    loop {
        tokio::select! {
            () = shutdown.cancelled() => break,
            _ = ticks.tick() => {}
        }
        if let Err(error) = run_maintenance(db).await {
            tracing::error!(
                name: "jobs.maintenance.failed",
                error = %format_args!("{error:#}"),
                "failed to maintain the jobs",
            );
        }
    }
}

/// Queues the due scheduled jobs, rescues the jobs left running and deletes the old ones.
async fn run_maintenance(db: &PgPool) -> Result<(), InternalError> {
    schedules::queue_due(db).await?;
    rescue(db).await?;
    prune(db).await
}

/// Puts the jobs `executing` for longer than `RESCUE_AFTER` back in their queue, or fails those
/// with no attempts left.
async fn rescue(db: &PgPool) -> Result<(), InternalError> {
    let rescued = sqlx::query!(
        r#"
        UPDATE jobs
        SET state = CASE WHEN attempt < max_attempts THEN 'available'::job_state ELSE 'failed' END,
            finished_at = CASE WHEN attempt < max_attempts THEN NULL ELSE now() END
        WHERE state = 'executing' AND attempted_at < now() - make_interval(secs => $1)
        RETURNING id, kind, attempt, state = 'available' AS "will_retry!"
        "#,
        RESCUE_AFTER.as_secs_f64(),
    )
    .fetch_all(db)
    .await
    .context("failed to rescue the jobs left running")?;
    for job in rescued {
        let (kind, id, attempt) = (job.kind, job.id.0, job.attempt);
        if job.will_retry {
            tracing::warn!(
                name: "jobs.job.rescued",
                kind,
                %id,
                attempt,
                "the job's attempt never ended, and will retry",
            );
        } else {
            tracing::error!(
                name: "jobs.job.failed",
                kind,
                %id,
                attempt,
                "the job's last attempt never ended",
            );
        }
    }
    Ok(())
}

/// Deletes the jobs that finished more than `KEEP_FINISHED` ago.
async fn prune(db: &PgPool) -> Result<(), InternalError> {
    sqlx::query!(
        r#"
        DELETE FROM jobs
        WHERE state IN ('completed', 'failed', 'cancelled')
            AND finished_at < now() - make_interval(secs => $1)
        "#,
        KEEP_FINISHED.as_secs_f64(),
    )
    .execute(db)
    .await
    .context("failed to delete the old jobs")?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::future;

    use super::*;

    const TIMEOUT: Duration = Duration::from_mins(1);

    mod supervise {
        use super::*;

        #[tokio::test]
        async fn returns_how_the_work_ended() {
            let ended = supervise(TIMEOUT, async { Err(JobError::Cancel("done".to_owned())) });

            assert!(matches!(ended.await, Err(JobError::Cancel(reason)) if reason == "done"));
        }

        #[tokio::test]
        async fn turns_a_panic_into_a_failed_attempt() {
            let ended = supervise(TIMEOUT, async { panic!("the job broke") }).await;

            let Err(JobError::Internal(error)) = ended else {
                panic!("expected a failed attempt, got {ended:?}");
            };
            assert_eq!(error.to_string(), "panicked: the job broke");
        }

        #[tokio::test]
        async fn turns_a_timeout_into_a_failed_attempt() {
            let ended = supervise(Duration::from_millis(10), future::pending()).await;

            let Err(JobError::Internal(error)) = ended else {
                panic!("expected a failed attempt, got {ended:?}");
            };
            assert_eq!(error.to_string(), "timed out after 10ms");
        }
    }

    mod record {
        use super::*;

        /// Inserts a job the runner claimed for its `attempt`th attempt out of `max_attempts`.
        async fn claimed_job(db: &PgPool, attempt: i32, max_attempts: i32) -> ClaimedJob {
            sqlx::query_as!(
                ClaimedJob,
                r#"
                INSERT INTO jobs (queue, kind, state, attempt, max_attempts, attempted_at)
                VALUES ('default', 'test', 'executing', $1, $2, now())
                RETURNING id, kind, args, attempt, max_attempts
                "#,
                attempt,
                max_attempts,
            )
            .fetch_one(db)
            .await
            .unwrap()
        }

        /// Returns the job's state, and the seconds until its next attempt, or None once it
        /// finished.
        async fn job_state(db: &PgPool, id: JobId) -> (JobState, Option<f64>) {
            let row = sqlx::query!(
                r#"
                SELECT
                    state,
                    CASE WHEN finished_at IS NULL
                        THEN extract(epoch FROM run_at - now())::float8
                    END AS wait
                FROM jobs WHERE id = $1
                "#,
                id as JobId,
            )
            .fetch_one(db)
            .await
            .unwrap();
            (row.state, row.wait)
        }

        #[sqlx::test]
        async fn completes_a_job_that_succeeded(db: PgPool) {
            let job = claimed_job(&db, 1, 3).await;

            record(&db, &job, Ok(())).await;

            assert_eq!(job_state(&db, job.id).await, (JobState::Completed, None));
        }

        #[sqlx::test]
        async fn retries_a_failed_attempt_after_a_backoff(db: PgPool) {
            let job = claimed_job(&db, 2, 3).await;

            record(&db, &job, Err(anyhow!("down").into())).await;

            let (state, wait) = job_state(&db, job.id).await;
            assert_eq!(state, JobState::Available);
            // 2⁴ + 15 seconds, plus up to 10%
            let wait = wait.unwrap();
            assert!((30.0..=34.1).contains(&wait), "waits {wait} s");
        }

        #[sqlx::test]
        async fn fails_the_job_after_its_last_attempt(db: PgPool) {
            let job = claimed_job(&db, 3, 3).await;

            record(&db, &job, Err(anyhow!("down").into())).await;

            assert_eq!(job_state(&db, job.id).await, (JobState::Failed, None));
        }

        #[sqlx::test]
        async fn fails_the_job_at_once_on_a_permanent_failure(db: PgPool) {
            let job = claimed_job(&db, 1, 3).await;

            record(&db, &job, Err(JobError::Fail(anyhow!("never works")))).await;

            assert_eq!(job_state(&db, job.id).await, (JobState::Failed, None));
        }

        #[sqlx::test]
        async fn cancels_a_job_that_cancelled_itself(db: PgPool) {
            let job = claimed_job(&db, 1, 3).await;

            record(&db, &job, Err(JobError::Cancel("nothing to do".to_owned()))).await;

            assert_eq!(job_state(&db, job.id).await, (JobState::Cancelled, None));
        }

        #[sqlx::test]
        async fn leaves_a_job_that_a_rescue_gave_to_its_next_attempt(db: PgPool) {
            let job = claimed_job(&db, 1, 3).await;
            sqlx::query!(
                "UPDATE jobs SET attempt = 2, attempted_at = now() WHERE id = $1",
                job.id as JobId,
            )
            .execute(&db)
            .await
            .unwrap();

            record(&db, &job, Ok(())).await;

            assert_eq!(job_state(&db, job.id).await.0, JobState::Executing);
        }
    }
}
