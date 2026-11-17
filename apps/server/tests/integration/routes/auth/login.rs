use axum::http::{StatusCode, header::SET_COOKIE};
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client, PASSWORD};

#[database_test]
async fn signs_the_browser_in_with_a_cookie_scripts_cannot_read(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);

    let credentials = json!({ "username": "ada", "password": PASSWORD });
    let response = browser.post("/api/auth/login", credentials).await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body["username"], "ada");
    let cookie = response.headers[SET_COOKIE].to_str().unwrap();
    assert!(cookie.contains("HttpOnly"), "{cookie}");
    assert!(cookie.contains("SameSite=Strict"), "{cookie}");
    assert!(!cookie.contains("Secure"), "{cookie}");
    let me = browser.get("/api/me").await;
    assert_eq!(me.body["id"], json!(user.id), "{me:?}");
}

#[database_test]
async fn sends_the_cookie_only_over_https_behind_an_https_proxy(db: PgPool) {
    let db = watch_club::db::instrument(db);
    support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.set_header("x-forwarded-proto", "https");

    let credentials = json!({ "username": "ada", "password": PASSWORD });
    let response = browser.post("/api/auth/login", credentials).await;

    let cookie = response.headers[SET_COOKIE].to_str().unwrap();
    assert!(cookie.contains("Secure"), "{cookie}");
}

#[database_test]
async fn refuses_wrong_credentials(db: PgPool) {
    let db = watch_club::db::instrument(db);
    support::create_user(&db, "ada").await;

    for (username, password) in [("ada", "wrong password"), ("bob", PASSWORD), ("", "")] {
        let mut browser = Client::new(&db);
        let credentials = json!({ "username": username, "password": password });
        let response = browser.post("/api/auth/login", credentials).await;

        assert_eq!(
            response.status,
            StatusCode::UNPROCESSABLE_ENTITY,
            "{username}"
        );
        assert_eq!(response.body["code"], "wrong_credentials");
        assert!(!response.headers.contains_key(SET_COOKIE));
    }
}
