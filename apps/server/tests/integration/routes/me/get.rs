use axum::http::{StatusCode, header::WWW_AUTHENTICATE};
use serde_json::json;
use watch_club::testing::database;

use crate::support::{self, Client};

#[tokio::test]
async fn returns_the_signed_in_user() {
    let db = database().await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser.get("/api/me").await;

    assert_eq!(response.status, StatusCode::OK);
    assert_eq!(
        response.body,
        json!({
            "id": user.id,
            "username": "ada",
            "locale": "en-US",
            "is_instance_administrator": false,
        })
    );
}

#[tokio::test]
async fn refuses_requests_without_a_session() {
    let db = database().await;
    let response = Client::new(&db).get("/api/me").await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
    assert_eq!(response.headers[WWW_AUTHENTICATE], "Bearer");
    assert_eq!(response.body["code"], "unauthorized");
}

#[tokio::test]
async fn refuses_requests_once_the_session_expired() {
    let db = database().await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;
    support::expire_sessions(&db, user.id).await;

    let response = browser.get("/api/me").await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
