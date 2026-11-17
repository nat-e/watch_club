use axum::http::StatusCode;
use serde_json::Value;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn needs_setup_until_the_instance_administrator_exists(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db).get("/api/instance").await;
    assert_eq!(response.status, StatusCode::OK);
    assert_eq!(response.body["needs_setup"], true);

    support::create_instance_administrator(&db).await;

    let response = Client::new(&db).get("/api/instance").await;
    assert_eq!(response.body["needs_setup"], false);
    assert_eq!(response.body["version"], env!("CARGO_PKG_VERSION"));
}

#[database_test]
async fn names_no_sentry_dsn_unless_the_host_sets_one(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db).get("/api/instance").await;
    assert_eq!(response.body["web_sentry_dsn"], Value::Null);

    let dsn = "https://key@sentry.example.com/1";
    let response = Client::with_web_sentry_dsn(&db, dsn)
        .get("/api/instance")
        .await;
    assert_eq!(response.body["web_sentry_dsn"], dsn);
}
