use axum::http::StatusCode;
use serde_json::{Value, json};
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client, PASSWORD};

fn password_change(current_password: &str, new_password: &str) -> Value {
    json!({ "current_password": current_password, "new_password": new_password })
}

/// Returns the status of a request to sign in as `username` with `password`.
async fn sign_in_status(client: &mut Client, username: &str, password: &str) -> StatusCode {
    let credentials = json!({ "username": username, "password": password });
    client.post("/api/auth/login", credentials).await.status
}

#[database_test]
async fn changes_the_password_and_signs_out_the_other_devices(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;
    let mut phone = Client::new(&db);
    phone.sign_in_app(&user).await;

    let response = browser
        .put(
            "/api/me/password",
            password_change(PASSWORD, "new password"),
        )
        .await;

    assert_eq!(response.status, StatusCode::NO_CONTENT, "{response:?}");
    assert_eq!(browser.get("/api/me").await.status, StatusCode::OK);
    assert_eq!(phone.get("/api/me").await.status, StatusCode::UNAUTHORIZED);
    let mut other = Client::new(&db);
    assert_eq!(
        sign_in_status(&mut other, "ada", PASSWORD).await,
        StatusCode::UNPROCESSABLE_ENTITY
    );
    assert_eq!(
        sign_in_status(&mut other, "ada", "new password").await,
        StatusCode::OK
    );
}

#[database_test]
async fn keeps_the_mobile_apps_session(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut phone = Client::new(&db);
    phone.sign_in_app(&user).await;

    let response = phone
        .put(
            "/api/me/password",
            password_change(PASSWORD, "new password"),
        )
        .await;

    assert_eq!(response.status, StatusCode::NO_CONTENT, "{response:?}");
    assert_eq!(phone.get("/api/me").await.status, StatusCode::OK);
}

#[database_test]
async fn refuses_a_wrong_current_password(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser
        .put(
            "/api/me/password",
            password_change("wrong password", "new password"),
        )
        .await;

    assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(response.body["code"], "wrong_password");
    assert_eq!(
        sign_in_status(&mut Client::new(&db), "ada", PASSWORD).await,
        StatusCode::OK
    );
}

#[database_test]
async fn says_which_rule_the_new_password_breaks(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser
        .put("/api/me/password", password_change(PASSWORD, "short"))
        .await;

    assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        response.body,
        json!({
            "code": "invalid_password",
            "message": "the password is shorter than 8 characters",
            "reason": { "code": "too_short", "min": 8 },
        })
    );
}

#[database_test]
async fn stops_the_password_reset_link(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let token = support::create_password_reset_link(&db, user.id).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    browser
        .put(
            "/api/me/password",
            password_change(PASSWORD, "new password"),
        )
        .await;

    let check = browser
        .get(&format!("/api/password-reset?token={token}"))
        .await;
    assert_eq!(check.body["username"], Value::Null);
}

#[database_test]
async fn refuses_visitors_who_are_not_signed_in(db: PgPool) {
    let db = watch_club::db::instrument(db);
    support::create_user(&db, "ada").await;

    let response = Client::new(&db)
        .put(
            "/api/me/password",
            password_change(PASSWORD, "new password"),
        )
        .await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
