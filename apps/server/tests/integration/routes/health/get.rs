use axum::http::StatusCode;
use serde_json::Value;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::Client;

#[database_test]
async fn says_the_server_works(db: PgPool) {
    let response = Client::new(&db).get("/api/health").await;

    assert_eq!(response.status, StatusCode::OK);
    assert_eq!(response.body, Value::Null);
}

#[database_test]
async fn says_the_server_cannot_reach_its_database(db: PgPool) {
    let mut client = Client::new(&db);
    db.close().await;

    let response = client.get("/api/health").await;

    assert_eq!(response.status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(response.body, Value::Null);
}
