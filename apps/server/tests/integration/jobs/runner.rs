use sqlx::PgPool;
use watch_club::jobs::{self, DeleteExpiredSessions, JobId};

use super::job_state;

/// Queues a job, then changes it with the SQL statement, which gets the job's ID as `$1`.
async fn enqueue_and_update(db: &PgPool, update: &'static str) -> JobId {
    let id = jobs::enqueue(db, DeleteExpiredSessions {}).await.unwrap();
    sqlx::query(update).bind(id).execute(db).await.unwrap();
    id
}

mod run_available {
    use super::*;

    #[sqlx::test]
    async fn runs_jobs_by_priority_then_in_the_order_they_are_due(db: PgPool) {
        let low = enqueue_and_update(&db, "UPDATE jobs SET priority = 5 WHERE id = $1").await;
        let second = jobs::enqueue(&db, DeleteExpiredSessions {}).await.unwrap();
        let first = enqueue_and_update(
            &db,
            "UPDATE jobs SET run_at = now() - interval '1 minute' WHERE id = $1",
        )
        .await;

        jobs::run_available(&db).await.unwrap();

        let order = sqlx::query_scalar!("SELECT id FROM jobs ORDER BY attempted_at")
            .fetch_all(&db)
            .await
            .unwrap();
        assert_eq!(order, [first, second, low]);
    }

    #[sqlx::test]
    async fn waits_for_the_time_a_job_runs_at(db: PgPool) {
        let id = enqueue_and_update(
            &db,
            "UPDATE jobs SET run_at = now() + interval '1 minute' WHERE id = $1",
        )
        .await;

        jobs::run_available(&db).await.unwrap();

        assert_eq!(job_state(&db, id).await, ("available".to_owned(), 0));
    }

    #[sqlx::test]
    async fn runs_each_job_once_when_runners_claim_at_the_same_time(db: PgPool) {
        for _ in 0..20 {
            jobs::enqueue(&db, DeleteExpiredSessions {}).await.unwrap();
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
                .all(|job| job.state == "completed" && job.attempt == 1)
        );
    }

    #[sqlx::test]
    async fn retries_a_job_whose_arguments_dont_read(db: PgPool) {
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

        assert_eq!(job_state(&db, id).await, ("available".to_owned(), 1));
    }

    #[sqlx::test]
    async fn rescues_a_job_left_running_for_an_hour(db: PgPool) {
        let id = enqueue_and_update(
            &db,
            "
            UPDATE jobs
            SET state = 'executing', attempt = 1, attempted_at = now() - interval '61 minutes'
            WHERE id = $1
            ",
        )
        .await;

        jobs::run_available(&db).await.unwrap();

        assert_eq!(job_state(&db, id).await, ("completed".to_owned(), 2));
    }

    #[sqlx::test]
    async fn leaves_a_job_running_for_less_than_an_hour(db: PgPool) {
        let id = enqueue_and_update(
            &db,
            "
            UPDATE jobs
            SET state = 'executing', attempt = 1, attempted_at = now() - interval '59 minutes'
            WHERE id = $1
            ",
        )
        .await;

        jobs::run_available(&db).await.unwrap();

        assert_eq!(job_state(&db, id).await, ("executing".to_owned(), 1));
    }

    #[sqlx::test]
    async fn fails_a_job_left_running_on_its_last_attempt(db: PgPool) {
        let id = enqueue_and_update(
            &db,
            "
            UPDATE jobs
            SET state = 'executing', attempt = 3, attempted_at = now() - interval '61 minutes'
            WHERE id = $1
            ",
        )
        .await;

        jobs::run_available(&db).await.unwrap();

        assert_eq!(job_state(&db, id).await, ("failed".to_owned(), 3));
    }

    #[sqlx::test]
    async fn deletes_the_jobs_finished_over_a_week_ago(db: PgPool) {
        for state in ["completed", "failed", "cancelled"] {
            let id = jobs::enqueue(&db, DeleteExpiredSessions {}).await.unwrap();
            sqlx::query!(
                r#"
                UPDATE jobs
                SET state = $2, finished_at = now() - interval '7 days 1 minute'
                WHERE id = $1
                "#,
                id as JobId,
                state,
            )
            .execute(&db)
            .await
            .unwrap();
        }
        let recent = enqueue_and_update(
            &db,
            "
            UPDATE jobs
            SET state = 'completed', finished_at = now() - interval '6 days'
            WHERE id = $1
            ",
        )
        .await;

        jobs::run_available(&db).await.unwrap();

        let left = sqlx::query_scalar!("SELECT id FROM jobs")
            .fetch_all(&db)
            .await
            .unwrap();
        assert_eq!(left, [recent]);
    }
}
