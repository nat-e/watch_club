use axum::http::{StatusCode, header::SET_COOKIE};
use serde_json::{Value, json};
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client, PASSWORD};

fn password_reset(token: &str, password: &str) -> Value {
    json!({ "token": token, "password": password })
}

/// Returns the status of a request to sign in as `username` with `password`.
async fn sign_in_status(db: &watch_club::db::Pool, username: &str, password: &str) -> StatusCode {
    let credentials = json!({ "username": username, "password": password });
    Client::new(db)
        .post("/api/auth/login", credentials)
        .await
        .status
}

#[database_test]
async fn sets_the_password_and_signs_the_user_out_everywhere(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;
    let mut phone = Client::new(&db);
    phone.sign_in_app(&user).await;
    let token = support::create_password_reset_link(&db, user.id).await;

    let response = browser
        .post(
            "/api/password-reset",
            password_reset(&token, "new password"),
        )
        .await;

    assert_eq!(response.status, StatusCode::NO_CONTENT, "{response:?}");
    assert!(response.headers.get(SET_COOKIE).is_none());
    assert_eq!(
        browser.get("/api/me").await.status,
        StatusCode::UNAUTHORIZED
    );
    assert_eq!(phone.get("/api/me").await.status, StatusCode::UNAUTHORIZED);
    assert_eq!(
        sign_in_status(&db, "ada", PASSWORD).await,
        StatusCode::UNPROCESSABLE_ENTITY
    );
    assert_eq!(
        sign_in_status(&db, "ada", "new password").await,
        StatusCode::OK
    );
}

#[database_test]
async fn works_once(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let token = support::create_password_reset_link(&db, user.id).await;
    Client::new(&db)
        .post(
            "/api/password-reset",
            password_reset(&token, "new password"),
        )
        .await;

    let response = Client::new(&db)
        .post(
            "/api/password-reset",
            password_reset(&token, "other password"),
        )
        .await;

    assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(response.body["code"], "link_no_longer_works");
    assert_eq!(
        sign_in_status(&db, "ada", "new password").await,
        StatusCode::OK
    );
}

#[database_test]
async fn refuses_an_expired_or_unknown_link(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let expired = support::create_password_reset_link(&db, user.id).await;
    support::expire_password_reset_link(&db, user.id).await;

    for token in [expired.as_str(), &"A".repeat(43), "not-a-token"] {
        let response = Client::new(&db)
            .post("/api/password-reset", password_reset(token, "new password"))
            .await;

        assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY, "{token}");
        assert_eq!(response.body["code"], "link_no_longer_works", "{token}");
    }
    assert_eq!(sign_in_status(&db, "ada", PASSWORD).await, StatusCode::OK);
}

#[database_test]
async fn says_which_rule_the_password_breaks(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let token = support::create_password_reset_link(&db, user.id).await;

    let response = Client::new(&db)
        .post("/api/password-reset", password_reset(&token, "short"))
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
    // The link still works, for a password that follows the rules
    let check = Client::new(&db)
        .get(&format!("/api/password-reset?token={token}"))
        .await;
    assert_eq!(check.body["username"], "ada");
}
