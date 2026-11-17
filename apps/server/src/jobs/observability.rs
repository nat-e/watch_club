//! What observes each run of a job: its span, which its logs and trace carry, and its Sentry scope.

use std::fmt::Display;

use tracing::Instrument;

use super::ClaimedJob;
use crate::observability;

/// Runs `run`, the job's attempt, in a span with the job's kind, ID and attempt, which its logs
/// show. Its Sentry reports carry them as tags, with an issue for each kind of job.
pub(super) fn instrument<F: Future>(job: &ClaimedJob, run: F) -> impl Future<Output = F::Output> {
    // At error level, so that it holds every log of the attempt whatever `RUST_LOG` filters out
    let span = tracing::error_span!(
        "job",
        job.kind = %job.kind,
        job.id = %job.id.0,
        job.attempt = job.attempt,
        job.max_attempts = job.max_attempts,
    );
    let tags: [(&str, &dyn Display); 3] = [
        ("job.kind", &job.kind),
        ("job.id", &job.id.0),
        ("job.attempt", &job.attempt),
    ];
    observability::with_error_scope(&tags, &job.kind, run.instrument(span))
}
