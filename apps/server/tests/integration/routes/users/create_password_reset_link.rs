use axum::http::StatusCode;
use serde_json::{Value, json};
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn creates_a_link_to_the_users_password_reset(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;

    let response = browser
        .post_without_body(&format!("/api/users/{}/password-reset-link", user.id))
        .await;

    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    let token = response.body["token"].as_str().unwrap();
    let check = Client::new(&db)
        .get(&format!("/api/password-reset?token={token}"))
        .await;
    assert_eq!(check.body, json!({ "username": "ada" }));
}

#[database_test]
async fn replaces_the_last_link(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let user = support::create_user(&db, "ada").await;
    let last = support::create_password_reset_link(&db, user.id).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;

    browser
        .post_without_body(&format!("/api/users/{}/password-reset-link", user.id))
        .await;

    let check = browser
        .get(&format!("/api/password-reset?token={last}"))
        .await;
    assert_eq!(check.body["username"], Value::Null);
}

#[database_test]
async fn says_when_there_is_no_such_user(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;
    browser.delete(&format!("/api/users/{}", user.id)).await;

    let response = browser
        .post_without_body(&format!("/api/users/{}/password-reset-link", user.id))
        .await;

    assert_eq!(response.status, StatusCode::NOT_FOUND);
    assert_eq!(response.body["code"], "user_not_found");
}

#[database_test]
async fn refuses_other_users(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let other = support::create_user(&db, "grace").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser
        .post_without_body(&format!("/api/users/{}/password-reset-link", other.id))
        .await;

    assert_eq!(response.status, StatusCode::FORBIDDEN);
}
