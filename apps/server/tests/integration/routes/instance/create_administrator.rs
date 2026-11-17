use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn creates_the_instance_administrator_and_signs_them_in(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut browser = Client::new(&db);

    let account = json!({ "username": "ada", "password": "secret password", "locale": "fr-FR" });
    let response = browser.post("/api/instance/administrator", account).await;

    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    assert_eq!(response.body["username"], "ada");
    assert_eq!(response.body["preferences"]["locale"], "fr-FR");
    assert_eq!(response.body["is_instance_administrator"], true);
    let me = browser.get("/api/me").await;
    assert_eq!(me.body["username"], "ada", "{me:?}");
}

#[database_test]
async fn refuses_once_watchclub_is_set_up(db: PgPool) {
    let db = watch_club::db::instrument(db);
    support::create_instance_administrator(&db).await;

    let account = json!({ "username": "ada", "password": "secret password", "locale": "en-US" });
    let response = Client::new(&db)
        .post("/api/instance/administrator", account)
        .await;

    assert_eq!(response.status, StatusCode::CONFLICT);
    assert_eq!(
        response.body["code"],
        "instance_administrator_already_exists"
    );
}

#[database_test]
async fn says_which_rules_the_account_breaks(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let account = json!({ "username": "Ada!", "password": "short", "locale": "en-US" });
    let response = Client::new(&db)
        .post("/api/instance/administrator", account)
        .await;

    assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        response.body,
        json!({
            "code": "invalid_fields",
            "message": "the username or password breaks the rules",
            "username": { "code": "invalid_characters" },
            "password": { "code": "too_short", "min": 8 },
        })
    );
}

#[database_test]
async fn refuses_a_locale_watchclub_does_not_have(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let account = json!({ "username": "ada", "password": "secret password", "locale": "de-DE" });
    let response = Client::new(&db)
        .post("/api/instance/administrator", account)
        .await;

    assert_eq!(response.status, StatusCode::BAD_REQUEST);
    assert_eq!(response.body["code"], "invalid_request");
}
