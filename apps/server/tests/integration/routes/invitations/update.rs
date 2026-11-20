use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn changes_the_max_uses(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;
    let invitation = support::create_invitation(&db, "FRIENDS", Some(1)).await;
    let uri = format!("/api/invitations/{invitation}");

    let raised = browser.patch(&uri, json!({ "max_uses": 3 })).await;
    let removed = browser.patch(&uri, json!({ "max_uses": null })).await;

    assert_eq!(raised.status, StatusCode::OK, "{raised:?}");
    assert_eq!(raised.body["max_uses"], 3);
    assert_eq!(removed.status, StatusCode::OK, "{removed:?}");
    assert_eq!(removed.body["max_uses"], json!(null));
    assert_eq!(removed.body["code"], "FRIENDS");
}

#[database_test]
async fn refuses_fewer_uses_than_the_users_it_created(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;
    let invitation = support::create_invitation(&db, "FRIENDS", None).await;
    for username in ["ada", "grace"] {
        let redemption = json!({
            "code": "FRIENDS", "username": username, "password": "secret password", "locale": "en-US",
        });
        Client::new(&db)
            .post("/api/invitations/redeem", redemption)
            .await;
    }
    let uri = format!("/api/invitations/{invitation}");

    let response = browser.patch(&uri, json!({ "max_uses": 1 })).await;

    assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(response.body["code"], "max_uses_below_uses");
    let exactly = browser.patch(&uri, json!({ "max_uses": 2 })).await;
    assert_eq!(exactly.status, StatusCode::OK, "{exactly:?}");
}

#[database_test]
async fn says_when_there_is_no_such_invitation(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let admin = support::create_instance_administrator(&db).await;
    let mut browser = Client::new(&db);
    browser.sign_in(&admin).await;
    let invitation = support::create_invitation(&db, "FRIENDS", None).await;
    browser
        .delete(&format!("/api/invitations/{invitation}"))
        .await;

    let response = browser
        .patch(
            &format!("/api/invitations/{invitation}"),
            json!({ "max_uses": 1 }),
        )
        .await;

    assert_eq!(response.status, StatusCode::NOT_FOUND);
    assert_eq!(response.body["code"], "not_found");
}

#[database_test]
async fn refuses_other_users(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;
    let invitation = support::create_invitation(&db, "FRIENDS", Some(1)).await;

    let response = browser
        .patch(
            &format!("/api/invitations/{invitation}"),
            json!({ "max_uses": null }),
        )
        .await;

    assert_eq!(response.status, StatusCode::FORBIDDEN);
}
