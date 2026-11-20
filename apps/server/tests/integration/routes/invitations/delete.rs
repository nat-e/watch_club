use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn deletes_the_invitation_and_keeps_the_users_it_created(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;
    let invitation = support::create_invitation(&db, "FRIENDS", None).await;
    let mut invitee = Client::new(&db);
    let redemption = json!({
        "code": "FRIENDS", "username": "ada", "password": "secret password", "locale": "en-US",
    });
    invitee.post("/api/invitations/redeem", redemption).await;

    let response = browser
        .delete(&format!("/api/invitations/{invitation}"))
        .await;

    assert_eq!(response.status, StatusCode::NO_CONTENT);
    assert_eq!(browser.get("/api/invitations").await.body, json!([]));
    let check = Client::new(&db)
        .get("/api/invitations/redeemable?code=FRIENDS")
        .await;
    assert_eq!(check.body["redeemable"], false);
    assert_eq!(invitee.get("/api/me").await.body["username"], "ada");
}

#[database_test]
async fn says_when_there_is_no_such_invitation(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;
    let invitation = support::create_invitation(&db, "FRIENDS", None).await;
    let uri = format!("/api/invitations/{invitation}");
    browser.delete(&uri).await;

    let response = browser.delete(&uri).await;

    assert_eq!(response.status, StatusCode::NOT_FOUND);
    assert_eq!(response.body["code"], "not_found");
}

#[database_test]
async fn refuses_other_users(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;
    let invitation = support::create_invitation(&db, "FRIENDS", None).await;

    let response = browser
        .delete(&format!("/api/invitations/{invitation}"))
        .await;

    assert_eq!(response.status, StatusCode::FORBIDDEN);
}
