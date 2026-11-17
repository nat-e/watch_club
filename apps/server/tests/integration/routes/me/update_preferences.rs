use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn saves_the_users_locale(db: PgPool) {
    let db = watch_club::db::instrument(db);
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

#[database_test]
async fn refuses_a_locale_watchclub_does_not_have(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser
        .put("/api/me/preferences", json!({ "locale": "de-DE" }))
        .await;

    assert_eq!(response.status, StatusCode::BAD_REQUEST);
}

#[database_test]
async fn refuses_requests_without_a_session(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db)
        .put("/api/me/preferences", json!({ "locale": "fr-FR" }))
        .await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
