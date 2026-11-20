use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn lists_the_invitations_that_can_still_be_redeemed(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;
    support::create_invitation(&db, "FIRST", None).await;
    let expired = support::create_invitation(&db, "EXPIRED", None).await;
    support::expire_invitation(&db, expired).await;
    support::create_invitation(&db, "USED", Some(1)).await;
    let redemption = json!({
        "code": "USED", "username": "ada", "password": "secret password", "locale": "en-US",
    });
    Client::new(&db)
        .post("/api/invitations/redeem", redemption)
        .await;
    support::create_invitation(&db, "SECOND", Some(3)).await;

    let response = browser.get("/api/invitations").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    let codes: Vec<_> = response
        .body
        .as_array()
        .unwrap()
        .iter()
        .map(|invitation| invitation["code"].as_str().unwrap())
        .collect();
    assert_eq!(codes, ["FIRST", "SECOND"]);
    assert_eq!(response.body[1]["max_uses"], 3);
    assert_eq!(response.body[1]["uses"], 0);
}

#[database_test]
async fn refuses_other_users(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser.get("/api/invitations").await;

    assert_eq!(response.status, StatusCode::FORBIDDEN);
    assert_eq!(response.body["code"], "forbidden");
}

#[database_test]
async fn refuses_visitors_who_are_not_signed_in(db: PgPool) {
    let db = watch_club::db::instrument(db);

    let response = Client::new(&db).get("/api/invitations").await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
