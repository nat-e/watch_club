use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn says_whose_password_the_link_resets(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let token = support::create_password_reset_link(&db, user.id).await;

    let response = Client::new(&db)
        .get(&format!("/api/password-reset?token={token}"))
        .await;

    assert_eq!(response.status, StatusCode::OK);
    assert_eq!(response.body, json!({ "username": "ada" }));
}

#[database_test]
async fn says_nobody_once_the_link_no_longer_works(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let ada = support::create_user(&db, "ada").await;
    let expired = support::create_password_reset_link(&db, ada.id).await;
    support::expire_password_reset_link(&db, ada.id).await;
    let grace = support::create_user(&db, "grace").await;
    let used = support::create_password_reset_link(&db, grace.id).await;
    Client::new(&db)
        .post(
            "/api/password-reset",
            json!({ "token": used, "password": "new password" }),
        )
        .await;
    let unknown = "A".repeat(43);

    for token in [expired.as_str(), used.as_str(), &unknown, "not-a-token"] {
        let response = Client::new(&db)
            .get(&format!("/api/password-reset?token={token}"))
            .await;

        assert_eq!(response.status, StatusCode::OK, "{token}");
        assert_eq!(response.body, json!({ "username": null }), "{token}");
    }
}
