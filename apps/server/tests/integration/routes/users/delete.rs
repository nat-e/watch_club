use axum::http::StatusCode;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn deletes_the_user_and_signs_them_out(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;
    let mut users_app = Client::new(&db);
    users_app.sign_in_app(&user).await;

    let response = browser.delete(&format!("/api/users/{}", user.id)).await;

    assert_eq!(response.status, StatusCode::NO_CONTENT);
    let users = browser.get("/api/users").await;
    assert_eq!(users.body.as_array().unwrap().len(), 1);
    assert_eq!(
        users_app.get("/api/me").await.status,
        StatusCode::UNAUTHORIZED
    );
}

#[database_test]
async fn refuses_to_delete_the_instance_administrator(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;

    let response = browser.delete(&format!("/api/users/{}", admin.id)).await;

    assert_eq!(response.status, StatusCode::CONFLICT);
    assert_eq!(response.body["code"], "cannot_delete_administrator");
    assert_eq!(browser.get("/api/me").await.status, StatusCode::OK);
}

#[database_test]
async fn says_when_there_is_no_such_user(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;
    let uri = format!("/api/users/{}", user.id);
    browser.delete(&uri).await;

    let response = browser.delete(&uri).await;

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

    let response = browser.delete(&format!("/api/users/{}", other.id)).await;

    assert_eq!(response.status, StatusCode::FORBIDDEN);
}
