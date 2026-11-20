use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn says_whether_the_invitation_can_be_redeemed(db: PgPool) {
    let db = watch_club::db::instrument(db);
    support::create_invitation(&db, "FRIENDS", None).await;
    let expired = support::create_invitation(&db, "EXPIRED", None).await;
    support::expire_invitation(&db, expired).await;
    support::create_invitation(&db, "USED", Some(1)).await;
    let redemption = json!({
        "code": "USED", "username": "ada", "password": "secret password", "locale": "en-US",
    });
    Client::new(&db)
        .post("/api/invitations/redeem", redemption)
        .await;

    for (code, redeemable) in [
        ("FRIENDS", true),
        ("EXPIRED", false),
        ("USED", false),
        ("UNKNOWN", false),
    ] {
        let uri = format!("/api/invitations/redeemable?code={code}");
        let response = Client::new(&db).get(&uri).await;

        assert_eq!(response.status, StatusCode::OK, "{code}");
        assert_eq!(response.body, json!({ "redeemable": redeemable }), "{code}");
    }
}
