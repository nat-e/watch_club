//! What observes the jobs: each run's span and Sentry scope, and the metrics of the runs and of the
//! queues.

use std::{fmt::Display, slice, sync::LazyLock, time::Instant};

use anyhow::Context;
use opentelemetry::{
    KeyValue, global,
    metrics::{Gauge, Histogram, UpDownCounter},
};
use sqlx_otel::QueryAnnotateExt;
use tracing::Instrument;

use super::{ClaimedJob, Queue, runner::AttemptEnd};
use crate::{db::Pool, domain::InternalError, observability};

/// Runs `run`, the job's attempt, in a span with the job's kind, ID and attempt, which its logs
/// show. Its Sentry reports carry them as tags, with an issue for each kind of job. The metrics
/// count it as executing while it runs, then record how long it took and how it ended.
pub(super) async fn instrument(job: &ClaimedJob, run: impl Future<Output = AttemptEnd>) {
    // At error level, so that it holds every log of the attempt whatever `RUST_LOG` filters out
    let span = tracing::error_span!(
        "job",
        job.kind = %job.kind,
        job.id = %job.id.0,
        job.attempt = job.attempt,
        job.max_attempts = job.max_attempts,
    );
    // The tags only while the scope is made, as they can't be held across an `.await`
    let attempt = {
        let tags: [(&str, &dyn Display); 3] = [
            ("job.kind", &job.kind),
            ("job.id", &job.id.0),
            ("job.attempt", &job.attempt),
        ];
        observability::with_error_scope(&tags, &job.kind, run.instrument(span))
    };
    let queue = KeyValue::new("job.queue", job.queue.name());
    let _executing = Executing::start(queue.clone());
    let started = Instant::now();
    let end = attempt.await;
    METRICS.attempt_duration.record(
        started.elapsed().as_secs_f64(),
        &[
            KeyValue::new("job.kind", job.kind.clone()),
            queue,
            KeyValue::new("job.outcome", end.name()),
        ],
    );
}

/// Records how many due jobs each queue holds that no attempt has claimed yet, and how long the
/// oldest of them has waited.
pub(super) async fn record_waiting(db: &Pool) -> Result<(), InternalError> {
    let waiting = sqlx::query!(
        r#"
        SELECT
            queue AS "queue: String",
            count(*) AS "count!",
            extract(epoch FROM now() - min(run_at))::float8 AS "oldest_age!"
        FROM jobs
        WHERE state = 'available' AND run_at <= now()
        GROUP BY queue
        "#
    )
    .with_operation("SELECT", "jobs")
    .fetch_all(db)
    .await
    .context("failed to count the waiting jobs")?;
    for queue in Queue::ALL {
        // A queue without due jobs has no row. Text rather than `Queue`, so that a queue this
        // server doesn't know, such as a newer one's, is skipped rather than failing the query
        let (count, oldest_age) = waiting
            .iter()
            .find(|row| row.queue == queue.name())
            .map_or((0, 0.0), |row| (row.count, row.oldest_age));
        let attributes = [KeyValue::new("job.queue", queue.name())];
        METRICS.waiting.record(count, &attributes);
        METRICS.waiting_oldest_age.record(oldest_age, &attributes);
    }
    Ok(())
}

/// The jobs' metrics, made on first use, once `observability::start` has set where they go.
static METRICS: LazyLock<Metrics> = LazyLock::new(Metrics::new);

struct Metrics {
    attempt_duration: Histogram<f64>,
    executing: UpDownCounter<i64>,
    waiting: Gauge<i64>,
    waiting_oldest_age: Gauge<f64>,
}

impl Metrics {
    fn new() -> Self {
        let meter = global::meter(env!("CARGO_PKG_NAME"));
        Self {
            attempt_duration: meter
                .f64_histogram("jobs.attempt.duration")
                .with_unit("s")
                .with_description("The time each attempt of a job takes, by how it ended.")
                // From 10 ms to the hour after which an attempt counts as left behind, as the
                // default buckets suit milliseconds
                .with_boundaries(vec![
                    0.01, 0.05, 0.1, 0.5, 1.0, 5.0, 10.0, 30.0, 60.0, 300.0, 600.0, 1800.0, 3600.0,
                ])
                .build(),
            executing: meter
                .i64_up_down_counter("jobs.executing")
                .with_unit("{job}")
                .with_description("The jobs whose attempt is running.")
                .build(),
            waiting: meter
                .i64_gauge("jobs.waiting")
                .with_unit("{job}")
                .with_description("The jobs due to run that no attempt has claimed yet.")
                .build(),
            waiting_oldest_age: meter
                .f64_gauge("jobs.waiting.oldest_age")
                .with_unit("s")
                .with_description("The time the oldest of the waiting jobs has been due.")
                .build(),
        }
    }
}

/// A guard that counts an attempt as executing until it's dropped, even before the attempt ends,
/// as at shutdown.
struct Executing(KeyValue);

impl Executing {
    fn start(queue: KeyValue) -> Self {
        METRICS.executing.add(1, slice::from_ref(&queue));
        Self(queue)
    }
}

impl Drop for Executing {
    fn drop(&mut self) {
        METRICS.executing.add(-1, slice::from_ref(&self.0));
    }
}
