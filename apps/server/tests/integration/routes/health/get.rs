use std::time::{Duration, Instant};

use axum::http::StatusCode;
use serde_json::Value;
use sqlx::{PgPool, postgres::PgPoolOptions};
use watch_club_test_macros::database_test;

use crate::support::Client;

#[database_test]
async fn says_the_server_works(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db).get("/api/health").await;

    assert_eq!(response.status, StatusCode::OK);
    assert_eq!(response.body, Value::Null);
}

#[database_test]
async fn says_the_server_cannot_reach_its_database(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut client = Client::new(&db);
    db.close().await;

    let response = client.get("/api/health").await;

    assert_eq!(response.status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(response.body, Value::Null);
}

#[database_test]
async fn answers_before_docker_gives_up_while_every_connection_is_busy(db: PgPool) {
    // A pool of one connection, which the test holds
    let options = db.connect_options().as_ref().clone();
    let busy = PgPoolOptions::new()
        .max_connections(1)
        .connect_with(options)
        .await
        .unwrap();
    let _held = busy.acquire().await.unwrap();
    let db = watch_club::db::instrument(busy);

    let started = Instant::now();
    let response = Client::new(&db).get("/api/health").await;

    assert_eq!(response.status, StatusCode::SERVICE_UNAVAILABLE);
    // The `--timeout` of the Dockerfile's `HEALTHCHECK`
    assert!(started.elapsed() < Duration::from_secs(5));
}
