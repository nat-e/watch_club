//! The jobs that run on a schedule. The database keeps each schedule's next run, so a job is
//! queued once per run even with several servers, and once after downtime however many runs it
//! missed.

use anyhow::Context;
use croner::Cron;
use jiff::{Timestamp, tz::TimeZone};
use sqlx::PgPool;

use super::{AnyJob, SCHEDULES};
use crate::domain::InternalError;

/// A job that runs on a schedule.
pub(super) struct Schedule {
    /// The unique name the database keeps the schedule's next run under
    pub(super) name: &'static str,
    /// The cron expression of the schedule's runs, in UTC, such as `0 3 * * SUN`
    pub(super) cron: &'static str,
    pub(super) job: fn() -> AnyJob,
}

impl Schedule {
    /// Returns the schedule's first run after `time`.
    fn next_run_after(&self, time: Timestamp) -> anyhow::Result<Timestamp> {
        let name = self.name;
        let cron: Cron = self
            .cron
            .parse()
            .with_context(|| format!("the schedule {name} has an invalid cron expression"))?;
        let next = cron
            .find_next_occurrence(&time.to_zoned(TimeZone::UTC), false)
            .with_context(|| format!("failed to find the next run of the schedule {name}"))?;
        Ok(next.timestamp())
    }
}

/// Makes the database's schedules match `SCHEDULES`: adds the new ones, moves the next run of
/// those whose cron expression changed, and deletes those that are gone.
pub(super) async fn sync(db: &PgPool) -> Result<(), InternalError> {
    let now = sqlx::query_scalar!(r#"SELECT now() AS "now!""#)
        .fetch_one(db)
        .await
        .context("failed to read the database's time")?
        .to_jiff();
    let mut names = Vec::new();
    let mut crons = Vec::new();
    let mut next_runs = Vec::new();
    for schedule in SCHEDULES {
        names.push(schedule.name);
        crons.push(schedule.cron);
        next_runs.push(jiff_sqlx::Timestamp::from(schedule.next_run_after(now)?));
    }
    sqlx::query!(
        r#"
        WITH deleted AS (
            DELETE FROM job_schedules WHERE name <> ALL($1)
        )
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
    .context("failed to sync the job schedules")?;
    Ok(())
}

/// Queues the job of each schedule whose next run has come, and moves the schedule to its next
/// run after now.
pub(super) async fn queue_due(db: &PgPool) -> Result<(), InternalError> {
    let mut transaction = db.begin().await.context("failed to start a transaction")?;
    // Skips the schedules another server is queuing
    let due = sqlx::query!(
        r#"
        SELECT name, now() AS "now!"
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
        let Some(schedule) = SCHEDULES.iter().find(|schedule| schedule.name == row.name) else {
            continue;
        };
        super::insert(&mut *transaction, &(schedule.job)()).await?;
        let next_run = schedule.next_run_after(row.now.to_jiff())?;
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
        for schedule in SCHEDULES {
            assert!(
                schedule.next_run_after(Timestamp::now()).is_ok(),
                "{}",
                schedule.name
            );
        }
    }

    #[test]
    fn the_next_run_is_the_first_after_the_time() {
        let schedule = Schedule {
            name: "weekly",
            cron: "0 3 * * SUN",
            job: || super::super::DeleteExpiredSessions {}.into(),
        };
        // A Sunday, at the time it runs
        let time: Timestamp = "2026-11-15T03:00:00Z".parse().unwrap();

        let next_run = schedule.next_run_after(time).unwrap();

        assert_eq!(next_run, "2026-11-22T03:00:00Z".parse().unwrap());
    }
}
