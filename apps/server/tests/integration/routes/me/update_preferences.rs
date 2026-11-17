use axum::http::StatusCode;
use serde_json::json;
use watch_club::testing::database;

use crate::support::{self, Client};

#[tokio::test]
async fn saves_the_users_locale() {
    let db = database().await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser
        .put("/api/me/preferences", json!({ "locale": "fr-FR" }))
        .await;

    assert_eq!(response.status, StatusCode::OK);
    assert_eq!(response.body["locale"], "fr-FR");
    assert_eq!(browser.get("/api/me").await.body["locale"], "fr-FR");
}

#[tokio::test]
async fn refuses_a_locale_watchclub_does_not_have() {
    let db = database().await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser
        .put("/api/me/preferences", json!({ "locale": "de-DE" }))
        .await;

    assert_eq!(response.status, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn refuses_requests_without_a_session() {
    let db = database().await;
    let response = Client::new(&db)
        .put("/api/me/preferences", json!({ "locale": "fr-FR" }))
        .await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
