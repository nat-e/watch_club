//! The runner, which runs the queued jobs inside the server: each queue's jobs in parallel up to
//! its limit, with retries, and the maintenance that queues the scheduled jobs, rescues the jobs a
//! crash left running and deletes old ones.

use std::{any::Any, panic::AssertUnwindSafe, time::Duration};

use anyhow::{Context, anyhow};
use futures_util::{FutureExt, future};
use sqlx::PgPool;
use tokio::{
    task::{JoinError, JoinSet},
    time::{self, MissedTickBehavior},
};
use tokio_util::sync::CancellationToken;
use tracing::Level;

use super::{AnyJob, ClaimedJob, JobError, JobId, JobState, Queue, observability, schedules};
use crate::domain::InternalError;

/// The time after which a job still `executing` counts as left behind by a crash, or by a shutdown
/// that didn't wait for it, and runs again.
const RESCUE_AFTER: Duration = Duration::from_hours(1);

/// The longest an attempt runs, whatever the job's `TIMEOUT`: shorter than `RESCUE_AFTER`, so that
/// a job still running is never rescued and started a second time.
const MAX_TIMEOUT: Duration = RESCUE_AFTER.saturating_sub(Duration::from_mins(1));

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
    let jobs = async {
        schedules::sync_schedules(&db).await?;
        let queues = future::join_all(Queue::ALL.map(|queue| run_queue(&db, queue, &shutdown)));
        tokio::join!(queues, maintain(&db, &shutdown));
        Ok(())
    };
    let deadline = async {
        shutdown.cancelled().await;
        time::sleep(SHUTDOWN_WAIT).await;
    };
    tokio::select! {
        run_result = jobs => run_result,
        // Drops the jobs future, which stops the jobs still running
        () = deadline => {
            tracing::event!(
                name: "jobs.shutdown.timed_out",
                Level::WARN,
                "stopped the jobs still running at shutdown, which will run again later",
            );
            Ok(())
        }
    }
}

/// Does at once what the runner does over time, for tests: syncs the schedules, runs the
/// maintenance, then runs the due jobs one at a time, in the order the runner claims them, until
/// none is left.
pub async fn run_available(db: &PgPool) -> Result<(), InternalError> {
    schedules::sync_schedules(db).await?;
    run_maintenance(db).await?;
    for queue in Queue::ALL {
        while let Some(job) = claim_jobs(db, queue, 1).await?.pop() {
            run_job(db, job).await;
        }
    }
    Ok(())
}

/// Claims the queue's due jobs whenever it has room, and runs each in its own task, until
/// `shutdown` is cancelled. Then waits for the running jobs.
async fn run_queue(db: &PgPool, queue: Queue, shutdown: &CancellationToken) {
    let mut running_jobs = JoinSet::new();
    loop {
        while let Some(task_result) = running_jobs.try_join_next() {
            log_panic(task_result);
        }
        let free_slots = queue.limit() - running_jobs.len();
        let claimed = if free_slots == 0 {
            Vec::new()
        } else {
            claim_jobs(db, queue, free_slots)
                .await
                .unwrap_or_else(|error| {
                    tracing::event!(
                        name: "jobs.claim.failed",
                        Level::ERROR,
                        ?queue,
                        exception.message = %format_args!("{error:#}"),
                        "failed to claim jobs",
                    );
                    Vec::new()
                })
        };
        // Free slots left over: the queue has no other due job for now
        let queue_empty = claimed.len() < free_slots;
        for job in claimed {
            let db = db.clone();
            running_jobs.spawn(async move { run_job(&db, job).await });
        }
        tokio::select! {
            () = shutdown.cancelled() => break,
            () = time::sleep(POLL_INTERVAL), if queue_empty => {}
            Some(task_result) = running_jobs.join_next(), if !queue_empty => log_panic(task_result),
        }
    }
    while let Some(task_result) = running_jobs.join_next().await {
        log_panic(task_result);
    }
}

/// Logs the panic of a job's task. `run_attempt` catches the job's own panics, so this one comes from
/// the runner's code around the job, which then stays `executing` until it's rescued.
fn log_panic(task_result: Result<(), JoinError>) {
    if let Err(error) = task_result {
        tracing::event!(
            name: "jobs.task.panicked",
            Level::ERROR,
            exception.message = %format_args!("{error:#}"),
            "the runner panicked around a job, which will run again later",
        );
    }
}

/// Claims up to `limit` of the queue's due jobs, by priority and then by time. No other claim gets
/// them, even from another server.
async fn claim_jobs(
    db: &PgPool,
    queue: Queue,
    limit: usize,
) -> Result<Vec<ClaimedJob>, InternalError> {
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

/// Runs a claimed job, and saves how its attempt ended. Arguments that don't read count as a
/// failed attempt.
async fn run_job(db: &PgPool, mut job: ClaimedJob) {
    let args = job.args.take();
    let run = async {
        let outcome = match AnyJob::from_row(&job.kind, args) {
            Ok(any_job) => {
                let timeout = any_job.timeout().min(MAX_TIMEOUT);
                run_attempt(timeout, any_job.run(db)).await
            }
            Err(error) => Err(error.context("failed to read the job").into()),
        };
        save_outcome(db, &job, outcome).await;
    };
    observability::instrument(&job, run).await;
}

/// Runs a job's work under its timeout, and returns how it ended. A panic or a timeout counts as a
/// failed attempt.
async fn run_attempt(
    timeout: Duration,
    work: impl Future<Output = Result<(), JobError>>,
) -> Result<(), JobError> {
    match time::timeout(timeout, AssertUnwindSafe(work).catch_unwind()).await {
        Ok(Ok(outcome)) => outcome,
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

/// Saves how a job's attempt ended: completed, failed, or back in its queue to try again after a
/// backoff.
async fn save_outcome(db: &PgPool, job: &ClaimedJob, outcome: Result<(), JobError>) {
    let attempt = job.attempt;
    let state = next_state(attempt, job.max_attempts, outcome);
    // A retry waits `attempt⁴ + 15` seconds, plus up to 10% at random so that jobs that failed
    // together don't retry together. A job that's no longer this attempt's is left alone: after a
    // rescue, it belongs to the next attempt.
    let recorded = sqlx::query!(
        r#"
        UPDATE jobs
        SET state = $3,
            run_at = CASE WHEN $3 = 'available'::job_state
                THEN now() + make_interval(secs => (power(attempt, 4) + 15) * (1 + random() / 10))
                ELSE run_at
            END,
            finished_at = CASE WHEN $3 = 'available'::job_state THEN NULL ELSE now() END
        WHERE id = $1 AND attempt = $2 AND state = 'executing'
        "#,
        job.id as JobId,
        attempt,
        state as JobState,
    )
    .execute(db)
    .await;
    if let Err(error) = recorded {
        tracing::event!(
            name: "jobs.save_outcome.failed",
            Level::ERROR,
            exception.message = %format_args!("{error:#}"),
            "failed to save how the job ended",
        );
    }
}

/// Returns the state an attempt that ended this way leaves its job in, and logs why it failed.
fn next_state(attempt: i16, max_attempts: i16, outcome: Result<(), JobError>) -> JobState {
    match outcome {
        Ok(()) => JobState::Completed,
        // The job's span holds its kind, ID and attempt
        Err(JobError::NonRetryable(error)) => {
            tracing::event!(
                name: "jobs.job.failed",
                Level::ERROR,
                exception.message = %format_args!("{error:#}"),
                "the job failed for good",
            );
            JobState::Failed
        }
        Err(JobError::Retryable(error)) if attempt < max_attempts => {
            tracing::event!(
                name: "jobs.attempt.failed",
                Level::WARN,
                exception.message = %format_args!("{error:#}"),
                "the job's attempt failed, and will retry",
            );
            JobState::Available
        }
        Err(JobError::Retryable(error)) => {
            tracing::event!(
                name: "jobs.job.failed",
                Level::ERROR,
                exception.message = %format_args!("{error:#}"),
                "the job's last attempt failed",
            );
            JobState::Failed
        }
    }
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
            tracing::event!(
                name: "jobs.maintenance.failed",
                Level::ERROR,
                exception.message = %format_args!("{error:#}"),
                "failed to maintain the jobs",
            );
        }
    }
}

/// Queues the due scheduled jobs, rescues the jobs left running and deletes the old ones.
async fn run_maintenance(db: &PgPool) -> Result<(), InternalError> {
    schedules::enqueue_due(db).await?;
    rescue_jobs(db).await?;
    delete_old_jobs(db).await
}

/// Puts the jobs `executing` for longer than `RESCUE_AFTER` back in their queue, or fails those
/// with no attempts left.
async fn rescue_jobs(db: &PgPool) -> Result<(), InternalError> {
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
    // No job's span holds these logs, so they carry its fields themselves
    for job in rescued {
        let (kind, id, attempt) = (job.kind, job.id.0, job.attempt);
        if job.will_retry {
            tracing::event!(
                name: "jobs.job.rescued",
                Level::WARN,
                job.kind = %kind,
                job.id = %id,
                job.attempt = attempt,
                "the job's attempt never ended, and will retry",
            );
        } else {
            tracing::event!(
                name: "jobs.job.failed",
                Level::ERROR,
                job.kind = %kind,
                job.id = %id,
                job.attempt = attempt,
                "the job's last attempt never ended",
            );
        }
    }
    Ok(())
}

/// Deletes the jobs that finished more than `KEEP_FINISHED` ago.
async fn delete_old_jobs(db: &PgPool) -> Result<(), InternalError> {
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

    mod run_attempt {
        use super::*;

        #[tokio::test]
        async fn returns_how_the_work_ended() {
            let outcome = run_attempt(TIMEOUT, async {
                Err(JobError::NonRetryable(anyhow!("invalid arguments")))
            });

            assert!(matches!(outcome.await, Err(JobError::NonRetryable(_))));
        }

        #[tokio::test]
        async fn turns_a_panic_into_a_failed_attempt() {
            let outcome = run_attempt(TIMEOUT, async { panic!("the job broke") }).await;

            let Err(JobError::Retryable(error)) = outcome else {
                panic!("expected a failed attempt, got {outcome:?}");
            };
            assert_eq!(error.to_string(), "panicked: the job broke");
        }

        #[tokio::test]
        async fn turns_a_timeout_into_a_failed_attempt() {
            let outcome = run_attempt(Duration::from_millis(10), future::pending()).await;

            let Err(JobError::Retryable(error)) = outcome else {
                panic!("expected a failed attempt, got {outcome:?}");
            };
            assert_eq!(error.to_string(), "timed out after 10ms");
        }
    }

    mod next_state {
        use super::*;

        #[test]
        fn completes_a_job_that_succeeded() {
            assert_eq!(next_state(1, 3, Ok(())), JobState::Completed);
        }

        #[test]
        fn retries_a_failed_attempt_with_attempts_left() {
            let state = next_state(2, 3, Err(anyhow!("down").into()));

            assert_eq!(state, JobState::Available);
        }

        #[test]
        fn fails_the_job_after_its_last_attempt() {
            let state = next_state(3, 3, Err(anyhow!("down").into()));

            assert_eq!(state, JobState::Failed);
        }

        #[test]
        fn fails_the_job_at_once_on_a_non_retryable_failure() {
            let failure = JobError::NonRetryable(anyhow!("never works"));

            assert_eq!(next_state(1, 3, Err(failure)), JobState::Failed);
        }
    }
}
