use axum::http::StatusCode;
use serde_json::Value;
use sqlx::PgPool;
use watch_club::AppsSentry;
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
    assert_eq!(response.body["mobile_sentry_dsn"], Value::Null);

    let apps_sentry = AppsSentry {
        web_dsn: Some("https://key@sentry.example.com/1".into()),
        mobile_dsn: Some("https://key@sentry.example.com/2".into()),
        environment: "staging".into(),
    };
    let response = Client::with_apps_sentry(&db, apps_sentry)
        .get("/api/instance")
        .await;
    assert_eq!(
        response.body["web_sentry_dsn"],
        "https://key@sentry.example.com/1"
    );
    assert_eq!(
        response.body["mobile_sentry_dsn"],
        "https://key@sentry.example.com/2"
    );
    assert_eq!(response.body["sentry_environment"], "staging");
}
