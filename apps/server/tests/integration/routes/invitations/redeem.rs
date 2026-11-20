use axum::http::StatusCode;
use serde_json::{Value, json};
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

fn redemption(code: &str, username: &str) -> Value {
    json!({ "code": code, "username": username, "password": "secret password", "locale": "fr-FR" })
}

#[database_test]
async fn creates_the_user_and_signs_them_in(db: PgPool) {
    let db = watch_club::db::instrument(db);
    support::create_invitation(&db, "FRIENDS", None).await;
    let mut browser = Client::new(&db);

    let response = browser
        .post("/api/invitations/redeem", redemption("FRIENDS", "ada"))
        .await;

    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    assert_eq!(response.body["username"], "ada");
    assert_eq!(response.body["is_instance_administrator"], false);
    assert_eq!(response.body["preferences"]["locale"], "fr-FR");
    let me = browser.get("/api/me").await;
    assert_eq!(me.body["username"], "ada", "{me:?}");
}

#[database_test]
async fn stops_at_the_max_uses(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    support::create_invitation(&db, "FRIENDS", Some(2)).await;

    let mut statuses = Vec::new();
    for username in ["ada", "grace", "hedy"] {
        let response = Client::new(&db)
            .post("/api/invitations/redeem", redemption("FRIENDS", username))
            .await;
        statuses.push((response.status, response.body["code"].clone()));
    }

    assert_eq!(
        statuses,
        [
            (StatusCode::CREATED, json!(null)),
            (StatusCode::CREATED, json!(null)),
            (
                StatusCode::UNPROCESSABLE_ENTITY,
                json!("invitation_not_redeemable")
            ),
        ]
    );
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;
    let users = browser.get("/api/users").await;
    assert_eq!(users.body.as_array().unwrap().len(), 3);
}

#[database_test]
async fn refuses_an_expired_or_unknown_invitation(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let expired = support::create_invitation(&db, "EXPIRED", None).await;
    support::expire_invitation(&db, expired).await;

    for code in ["EXPIRED", "UNKNOWN"] {
        let response = Client::new(&db)
            .post("/api/invitations/redeem", redemption(code, "ada"))
            .await;

        assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY, "{code}");
        assert_eq!(response.body["code"], "invitation_not_redeemable", "{code}");
    }
}

#[database_test]
async fn refuses_a_taken_username_and_gives_the_use_back(db: PgPool) {
    let db = watch_club::db::instrument(db);
    support::create_user(&db, "ada").await;
    support::create_invitation(&db, "FRIENDS", Some(1)).await;

    let response = Client::new(&db)
        .post("/api/invitations/redeem", redemption("FRIENDS", "ada"))
        .await;

    assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(response.body["code"], "username_taken");
    let check = Client::new(&db)
        .get("/api/invitations/redeemable?code=FRIENDS")
        .await;
    assert_eq!(check.body["redeemable"], true);
}

#[database_test]
async fn says_which_rules_the_account_breaks(db: PgPool) {
    let db = watch_club::db::instrument(db);
    support::create_invitation(&db, "FRIENDS", None).await;
    let account =
        json!({ "code": "FRIENDS", "username": "Ada!", "password": "short", "locale": "en-US" });

    let response = Client::new(&db)
        .post("/api/invitations/redeem", account)
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
