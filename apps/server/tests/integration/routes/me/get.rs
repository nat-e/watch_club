use axum::http::{StatusCode, header::WWW_AUTHENTICATE};
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn returns_the_signed_in_user(db: PgPool) {
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

#[database_test]
async fn refuses_requests_without_a_session(db: PgPool) {
    let response = Client::new(&db).get("/api/me").await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
    assert_eq!(response.headers[WWW_AUTHENTICATE], "Bearer");
    assert_eq!(response.body["code"], "unauthorized");
}

#[database_test]
async fn refuses_requests_once_the_session_expired(db: PgPool) {
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;
    support::expire_sessions(&db, user.id).await;

    let response = browser.get("/api/me").await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
