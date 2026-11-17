//! The jobs that run on a schedule. The database keeps each schedule's next run, so a job is
//! queued once per run even with several servers, and once after downtime however many runs it
//! missed.

use std::collections::BTreeMap;

use anyhow::Context;
use croner::Cron;
use jiff::{Timestamp, tz::TimeZone};
use sqlx::PgPool;

use super::NewJob;
use crate::domain::InternalError;

/// Returns the cron expression and job of each schedule, by the name the database keeps its next
/// run under: its job's kind.
fn schedules_by_name() -> anyhow::Result<BTreeMap<&'static str, (&'static str, NewJob)>> {
    let schedules = super::schedules().context("failed to serialize a scheduled job")?;
    Ok(schedules
        .into_iter()
        .map(|(cron, job)| (job.kind, (cron, job)))
        .collect())
}

/// Returns the first run of the cron expression after `time`.
fn next_run_after(cron: &str, time: Timestamp) -> anyhow::Result<Timestamp> {
    let parsed: Cron = cron
        .parse()
        .with_context(|| format!("{cron} isn't a valid cron expression"))?;
    let next = parsed
        .find_next_occurrence(&time.to_zoned(TimeZone::UTC), false)
        .with_context(|| format!("failed to find the next run of {cron}"))?;
    Ok(next.timestamp())
}

/// Makes the database's schedules match the code's: adds the new ones, moves the next run of
/// those whose cron expression changed, and deletes those that are gone.
pub(super) async fn sync_schedules(db: &PgPool) -> Result<(), InternalError> {
    // The server's clock, as other job queues use: with clocks out of sync, a run around the
    // server's start could be skipped or come early, and `enqueue_due` sets the next ones right
    let now = Timestamp::now();
    let schedules = schedules_by_name()?;
    let mut names = Vec::with_capacity(schedules.len());
    let mut crons = Vec::with_capacity(schedules.len());
    let mut next_runs = Vec::with_capacity(schedules.len());
    for (name, (cron, _)) in schedules {
        let next_run =
            next_run_after(cron, now).with_context(|| format!("failed to schedule {name}"))?;
        names.push(name);
        crons.push(cron);
        next_runs.push(jiff_sqlx::Timestamp::from(next_run));
    }
    // Syncing again gives the same result, so a failure between the two statements leaves nothing
    // wrong: the next start syncs again
    sqlx::query!(
        "DELETE FROM job_schedules WHERE name <> ALL($1)",
        &names as &[&str],
    )
    .execute(db)
    .await
    .context("failed to delete the job schedules gone from the code")?;
    sqlx::query!(
        r#"
        INSERT INTO job_schedules (name, cron, next_run_at)
        SELECT * FROM unnest($1::text[], $2::text[], $3::timestamptz[])
        ON CONFLICT (name) DO UPDATE
        SET cron = excluded.cron, next_run_at = excluded.next_run_at
        WHERE job_schedules.cron <> excluded.cron
        "#,
        &names as &[&str],
        &crons as &[&str],
        &next_runs as &[jiff_sqlx::Timestamp],
    )
    .execute(db)
    .await
    .context("failed to save the job schedules")?;
    Ok(())
}

/// Queues the job of each schedule whose next run has come, and moves the schedule to its next
/// run after now. The next run comes from the stored cron expression, which a server with newer
/// code may have changed.
pub(super) async fn enqueue_due(db: &PgPool) -> Result<(), InternalError> {
    let mut schedules = schedules_by_name()?;
    let mut transaction = db.begin().await.context("failed to start a transaction")?;
    // Skips the schedules another server is queuing
    let due = sqlx::query!(
        r#"
        SELECT name, cron, now() AS "now!"
        FROM job_schedules
        WHERE next_run_at <= now()
        FOR UPDATE SKIP LOCKED
        "#
    )
    .fetch_all(&mut *transaction)
    .await
    .context("failed to find the due job schedules")?;
    for row in due {
        // A server with newer code may have added it
        let Some((_, job)) = schedules.remove(row.name.as_str()) else {
            continue;
        };
        job.insert(&mut *transaction).await?;
        let next_run = next_run_after(&row.cron, row.now.to_jiff())?;
        sqlx::query!(
            "UPDATE job_schedules SET next_run_at = $2 WHERE name = $1",
            row.name,
            jiff_sqlx::Timestamp::from(next_run),
        )
        .execute(&mut *transaction)
        .await
        .context("failed to move a job schedule to its next run")?;
    }
    transaction
        .commit()
        .await
        .context("failed to queue the due scheduled jobs")?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_schedule_has_a_valid_cron_expression() {
        for (name, (cron, _)) in schedules_by_name().unwrap() {
            let next_run = next_run_after(cron, Timestamp::now());

            assert!(next_run.is_ok(), "{name}: {next_run:?}");
        }
    }

    #[test]
    fn the_next_run_is_the_first_after_the_time() {
        // A Sunday, at the time it runs
        let time: Timestamp = "2026-11-15T03:00:00Z".parse().unwrap();

        let next_run = next_run_after("0 3 * * SUN", time).unwrap();

        assert_eq!(next_run, "2026-11-22T03:00:00Z".parse().unwrap());
    }
}
