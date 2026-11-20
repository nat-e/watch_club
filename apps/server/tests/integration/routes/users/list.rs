use axum::http::StatusCode;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn lists_every_user_the_first_to_join_first(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser.get("/api/users").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    let users = response.body.as_array().unwrap();
    assert_eq!(users.len(), 2);
    assert_eq!(users[0]["id"], admin.id.to_string());
    assert_eq!(users[0]["username"], "admin");
    assert_eq!(users[0]["is_instance_administrator"], true);
    assert_eq!(users[1]["username"], "ada");
    assert_eq!(users[1]["is_instance_administrator"], false);
    assert!(users[1]["member_since"].is_string());
}

#[database_test]
async fn refuses_visitors_who_are_not_signed_in(db: PgPool) {
    let db = watch_club::db::instrument(db);

    let response = Client::new(&db).get("/api/users").await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
