//! Queuing and cancelling jobs, which `jobs::run_available` runs as the runner would.

mod runner;
mod schedules;

use sqlx::PgPool;
use watch_club::{
    domain::accounts,
    jobs::{self, DeleteExpiredSessions, JobId, JobState},
};
use watch_club_test_macros::database_test;

use crate::support::{self, PASSWORD};

/// Returns the job's state, and the number of times it started.
async fn job_state(db: &PgPool, id: JobId) -> (JobState, i16) {
    let job = sqlx::query!("SELECT state, attempt FROM jobs WHERE id = $1", id as JobId)
        .fetch_one(db)
        .await
        .unwrap();
    (job.state, job.attempt)
}

mod enqueue {
    use super::*;

    #[database_test]
    async fn queues_the_job_for_the_runner(db: PgPool) {
        let user = support::create_user(&db, "ada").await;
        accounts::sign_in(&db, "ada", PASSWORD.into())
            .await
            .unwrap();
        support::expire_sessions(&db, user.id).await;

        let id = jobs::enqueue(&db, DeleteExpiredSessions {}).await.unwrap();
        jobs::run_available(&db).await.unwrap();

        assert_eq!(job_state(&db, id).await, (JobState::Completed, 1));
        let sessions = sqlx::query_scalar!(r#"SELECT count(*) AS "count!" FROM sessions"#)
            .fetch_one(&db)
            .await
            .unwrap();
        assert_eq!(sessions, 0);
    }

    #[database_test]
    async fn queues_nothing_when_the_transaction_rolls_back(db: PgPool) {
        let mut transaction = db.begin().await.unwrap();

        jobs::enqueue(&mut *transaction, DeleteExpiredSessions {})
            .await
            .unwrap();
        transaction.rollback().await.unwrap();

        let queued = sqlx::query_scalar!(r#"SELECT count(*) AS "count!" FROM jobs"#)
            .fetch_one(&db)
            .await
            .unwrap();
        assert_eq!(queued, 0);
    }
}

mod cancel {
    use super::*;

    #[database_test]
    async fn cancels_a_queued_job(db: PgPool) {
        let id = jobs::enqueue(&db, DeleteExpiredSessions {}).await.unwrap();

        let cancelled = jobs::cancel(&db, id).await.unwrap();
        jobs::run_available(&db).await.unwrap();

        assert!(cancelled);
        assert_eq!(job_state(&db, id).await, (JobState::Cancelled, 0));
    }

    #[database_test]
    async fn is_too_late_once_the_job_ran(db: PgPool) {
        let id = jobs::enqueue(&db, DeleteExpiredSessions {}).await.unwrap();
        jobs::run_available(&db).await.unwrap();

        let cancelled = jobs::cancel(&db, id).await.unwrap();

        assert!(!cancelled);
        assert_eq!(job_state(&db, id).await, (JobState::Completed, 1));
    }
}
