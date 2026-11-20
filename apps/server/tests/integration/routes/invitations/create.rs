use axum::http::StatusCode;
use jiff::{SignedDuration, Timestamp};
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn creates_an_invitation_that_works_for_7_days(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;

    let response = browser
        .post("/api/invitations", json!({ "max_uses": 5 }))
        .await;

    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    assert_eq!(response.body["code"].as_str().unwrap().len(), 16);
    assert_eq!(response.body["max_uses"], 5);
    assert_eq!(response.body["uses"], 0);
    let expires_at: Timestamp = response.body["expires_at"]
        .as_str()
        .unwrap()
        .parse()
        .unwrap();
    let lifetime = expires_at.duration_since(Timestamp::now());
    assert!(
        lifetime > SignedDuration::from_hours(24 * 7 - 1),
        "{lifetime}"
    );
    let listed = browser.get("/api/invitations").await;
    assert_eq!(listed.body, json!([response.body]));
}

#[database_test]
async fn creates_an_invitation_without_a_limit(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;

    let response = browser
        .post("/api/invitations", json!({ "max_uses": null }))
        .await;

    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    assert_eq!(response.body["max_uses"], json!(null));
}

#[database_test]
async fn refuses_a_limit_of_0(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;

    let response = browser
        .post("/api/invitations", json!({ "max_uses": 0 }))
        .await;

    assert_eq!(response.status, StatusCode::BAD_REQUEST);
}

#[database_test]
async fn refuses_other_users(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser
        .post("/api/invitations", json!({ "max_uses": null }))
        .await;

    assert_eq!(response.status, StatusCode::FORBIDDEN);
}
