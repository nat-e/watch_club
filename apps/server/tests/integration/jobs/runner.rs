//! The runner, through `jobs::run_available`: the order it runs jobs in, its claims, rescues and
//! deletion of old jobs.

use sqlx::PgPool;
use watch_club::{
    jobs::{self, DeleteExpiredSessions, JobId, JobState},
    testing::database,
};

use super::job_state;

/// Queues a job that runs at once.
async fn enqueue(db: &PgPool) -> JobId {
    jobs::enqueue(db, DeleteExpiredSessions {}).await.unwrap()
}

mod run_available {
    use super::*;

    #[tokio::test]
    async fn runs_jobs_by_priority_then_in_the_order_they_are_due() {
        let db = database().await;
        let low = enqueue(&db).await;
        let second = enqueue(&db).await;
        let first = enqueue(&db).await;
        sqlx::query!("UPDATE jobs SET priority = 5 WHERE id = $1", low as JobId)
            .execute(&db)
            .await
            .unwrap();
        sqlx::query!(
            "UPDATE jobs SET run_at = now() - interval '1 minute' WHERE id = $1",
            first as JobId,
        )
        .execute(&db)
        .await
        .unwrap();

        jobs::run_available(&db).await.unwrap();

        let order = sqlx::query_scalar!("SELECT id FROM jobs ORDER BY attempted_at")
            .fetch_all(&db)
            .await
            .unwrap();
        assert_eq!(order, [first, second, low]);
    }

    #[tokio::test]
    async fn waits_for_the_time_a_job_runs_at() {
        let db = database().await;
        let id = enqueue(&db).await;
        sqlx::query!(
            "UPDATE jobs SET run_at = now() + interval '1 minute' WHERE id = $1",
            id as JobId,
        )
        .execute(&db)
        .await
        .unwrap();

        jobs::run_available(&db).await.unwrap();

        assert_eq!(job_state(&db, id).await, (JobState::Available, 0));
    }

    #[tokio::test]
    async fn runs_each_job_once_when_runners_claim_at_the_same_time() {
        let db = database().await;
        for _ in 0..20 {
            enqueue(&db).await;
        }

        let runs = tokio::join!(
            jobs::run_available(&db),
            jobs::run_available(&db),
            jobs::run_available(&db),
            jobs::run_available(&db),
        );

        runs.0.unwrap();
        runs.1.unwrap();
        runs.2.unwrap();
        runs.3.unwrap();
        // A job that two runners claimed would have started twice
        let jobs = sqlx::query!("SELECT state, attempt FROM jobs")
            .fetch_all(&db)
            .await
            .unwrap();
        assert_eq!(jobs.len(), 20);
        assert!(
            jobs.iter()
                .all(|job| job.state == JobState::Completed && job.attempt == 1)
        );
    }

    #[tokio::test]
    async fn retries_a_job_whose_arguments_dont_read() {
        let db = database().await;
        let id = sqlx::query_scalar!(
            r#"
            INSERT INTO jobs (queue, kind, max_attempts)
            VALUES ('default', 'removed_job', 3)
            RETURNING id
            "#
        )
        .fetch_one(&db)
        .await
        .unwrap();

        jobs::run_available(&db).await.unwrap();

        assert_eq!(job_state(&db, id).await, (JobState::Available, 1));
    }

    /// Makes the job look like an attempt that started this long ago and never ended.
    async fn leave_running(db: &PgPool, id: JobId, attempt: i16, started_ago: &str) {
        sqlx::query!(
            r#"
            UPDATE jobs
            SET state = 'executing', attempt = $2, attempted_at = now() - $3::text::interval
            WHERE id = $1
            "#,
            id as JobId,
            attempt,
            started_ago,
        )
        .execute(db)
        .await
        .unwrap();
    }

    #[tokio::test]
    async fn rescues_a_job_left_running_for_an_hour() {
        let db = database().await;
        let id = enqueue(&db).await;
        leave_running(&db, id, 1, "61 minutes").await;

        jobs::run_available(&db).await.unwrap();

        assert_eq!(job_state(&db, id).await, (JobState::Completed, 2));
    }

    #[tokio::test]
    async fn leaves_a_job_running_for_less_than_an_hour() {
        let db = database().await;
        let id = enqueue(&db).await;
        leave_running(&db, id, 1, "59 minutes").await;

        jobs::run_available(&db).await.unwrap();

        assert_eq!(job_state(&db, id).await, (JobState::Executing, 1));
    }

    #[tokio::test]
    async fn fails_a_job_left_running_on_its_last_attempt() {
        let db = database().await;
        let id = enqueue(&db).await;
        leave_running(&db, id, 3, "61 minutes").await;

        jobs::run_available(&db).await.unwrap();

        assert_eq!(job_state(&db, id).await, (JobState::Failed, 3));
    }

    /// Makes the job look like it ended in the state this long ago.
    async fn finish(db: &PgPool, id: JobId, state: JobState, finished_ago: &str) {
        sqlx::query!(
            r#"
            UPDATE jobs SET state = $2, finished_at = now() - $3::text::interval
            WHERE id = $1
            "#,
            id as JobId,
            state as JobState,
            finished_ago,
        )
        .execute(db)
        .await
        .unwrap();
    }

    #[tokio::test]
    async fn deletes_the_jobs_finished_over_a_week_ago() {
        let db = database().await;
        for state in [JobState::Completed, JobState::Failed, JobState::Cancelled] {
            let id = enqueue(&db).await;
            finish(&db, id, state, "7 days 1 minute").await;
        }
        let recent = enqueue(&db).await;
        finish(&db, recent, JobState::Completed, "6 days").await;

        jobs::run_available(&db).await.unwrap();

        let left = sqlx::query_scalar!("SELECT id FROM jobs")
            .fetch_all(&db)
            .await
            .unwrap();
        assert_eq!(left, [recent]);
    }
}
