//! The jobs that run on a schedule, through `jobs::run_available`, with the weekly cleanup of
//! expired sessions as the example.

use sqlx::PgPool;
use watch_club::jobs;
use watch_club::testing::database;

/// Returns the kinds of the jobs in the queue, finished or not.
async fn job_kinds(db: &PgPool) -> Vec<String> {
    sqlx::query_scalar!("SELECT kind FROM jobs")
        .fetch_all(db)
        .await
        .unwrap()
}

/// Returns whether the weekly cleanup of expired sessions runs next on the coming Sunday at 03:00
/// UTC.
async fn runs_next_on_the_coming_sunday(db: &PgPool) -> bool {
    sqlx::query_scalar!(
        r#"
        SELECT
            next_run_at > now()
            AND next_run_at <= now() + interval '7 days'
            AND to_char(next_run_at AT TIME ZONE 'UTC', 'Dy HH24:MI:SS') = 'Sun 03:00:00'
            AS "is_coming_sunday!"
        FROM job_schedules
        WHERE name = 'delete_expired_sessions'
        "#
    )
    .fetch_one(db)
    .await
    .unwrap()
}

/// Sets the next run of the weekly cleanup of expired sessions to now plus the interval, such as
/// `-3 weeks`.
async fn set_next_run_from_now(db: &PgPool, interval: &str) {
    sqlx::query!(
        r#"
        UPDATE job_schedules SET next_run_at = now() + $1::text::interval
        WHERE name = 'delete_expired_sessions'
        "#,
        interval,
    )
    .execute(db)
    .await
    .unwrap();
}

mod run_available {
    use super::*;

    #[tokio::test]
    async fn schedules_the_next_run_without_queuing_the_job() {
        let db = database().await;
        jobs::run_available(&db).await.unwrap();

        assert!(runs_next_on_the_coming_sunday(&db).await);
        assert_eq!(job_kinds(&db).await, Vec::<String>::new());
    }

    #[tokio::test]
    async fn queues_the_job_once_when_its_run_comes() {
        let db = database().await;
        jobs::run_available(&db).await.unwrap();
        set_next_run_from_now(&db, "-1 minute").await;

        let runs = tokio::join!(jobs::run_available(&db), jobs::run_available(&db));

        runs.0.unwrap();
        runs.1.unwrap();
        assert_eq!(job_kinds(&db).await, ["delete_expired_sessions"]);
        assert!(runs_next_on_the_coming_sunday(&db).await);
    }

    #[tokio::test]
    async fn queues_the_job_once_after_missing_several_runs() {
        let db = database().await;
        jobs::run_available(&db).await.unwrap();
        set_next_run_from_now(&db, "-3 weeks").await;

        jobs::run_available(&db).await.unwrap();

        assert_eq!(job_kinds(&db).await, ["delete_expired_sessions"]);
        assert!(runs_next_on_the_coming_sunday(&db).await);
    }

    #[tokio::test]
    async fn moves_the_next_run_when_the_cron_expression_changes() {
        let db = database().await;
        jobs::run_available(&db).await.unwrap();
        sqlx::query!(
            r#"
            UPDATE job_schedules
            SET cron = '0 0 1 1 *', next_run_at = now() + interval '1 year'
            WHERE name = 'delete_expired_sessions'
            "#
        )
        .execute(&db)
        .await
        .unwrap();

        jobs::run_available(&db).await.unwrap();

        let cron = sqlx::query_scalar!(
            "SELECT cron FROM job_schedules WHERE name = 'delete_expired_sessions'"
        )
        .fetch_one(&db)
        .await
        .unwrap();
        assert_eq!(cron, "0 3 * * SUN");
        assert!(runs_next_on_the_coming_sunday(&db).await);
    }

    #[tokio::test]
    async fn deletes_the_schedules_that_are_gone_from_the_code() {
        let db = database().await;
        sqlx::query!(
            r#"
            INSERT INTO job_schedules (name, cron, next_run_at)
            VALUES ('retired', '* * * * *', now() - interval '1 minute')
            "#
        )
        .execute(&db)
        .await
        .unwrap();

        jobs::run_available(&db).await.unwrap();

        let names = sqlx::query_scalar!("SELECT name FROM job_schedules")
            .fetch_all(&db)
            .await
            .unwrap();
        assert_eq!(names, ["delete_expired_sessions"]);
        assert_eq!(job_kinds(&db).await, Vec::<String>::new());
    }
}
