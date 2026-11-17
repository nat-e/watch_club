use axum::http::StatusCode;
use serde_json::Value;
use watch_club::testing::database;

use crate::support::{self, Client};

#[tokio::test]
async fn needs_setup_until_the_instance_administrator_exists() {
    let db = database().await;
    let response = Client::new(&db).get("/api/instance").await;
    assert_eq!(response.status, StatusCode::OK);
    assert_eq!(response.body["needs_setup"], true);

    support::create_instance_administrator(&db).await;

    let response = Client::new(&db).get("/api/instance").await;
    assert_eq!(response.body["needs_setup"], false);
    assert_eq!(response.body["version"], env!("CARGO_PKG_VERSION"));
}

#[tokio::test]
async fn names_no_sentry_dsn_unless_the_host_sets_one() {
    let db = database().await;
    let response = Client::new(&db).get("/api/instance").await;
    assert_eq!(response.body["web_sentry_dsn"], Value::Null);

    let dsn = "https://key@sentry.example.com/1";
    let response = Client::with_web_sentry_dsn(&db, dsn)
        .get("/api/instance")
        .await;
    assert_eq!(response.body["web_sentry_dsn"], dsn);
}
