use axum::http::StatusCode;
use serde_json::Value;
use watch_club::testing::database;

use crate::support::Client;

#[tokio::test]
async fn says_the_server_works() {
    let db = database().await;
    let response = Client::new(&db).get("/api/health").await;

    assert_eq!(response.status, StatusCode::OK);
    assert_eq!(response.body, Value::Null);
}

#[tokio::test]
async fn says_the_server_cannot_reach_its_database() {
    let db = database().await;
    let mut client = Client::new(&db);
    db.close().await;

    let response = client.get("/api/health").await;

    assert_eq!(response.status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(response.body, Value::Null);
}
