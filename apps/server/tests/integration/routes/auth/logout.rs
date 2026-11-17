use axum::http::StatusCode;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

#[database_test]
async fn ends_the_browsers_session(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;
    let mut copy = browser.clone();

    let response = browser.post_without_body("/api/auth/logout").await;

    assert_eq!(response.status, StatusCode::NO_CONTENT);
    assert_eq!(
        browser.get("/api/me").await.status,
        StatusCode::UNAUTHORIZED
    );
    // The session ends, so its cookie no longer signs anyone in
    assert_eq!(copy.get("/api/me").await.status, StatusCode::UNAUTHORIZED);
}

#[database_test]
async fn ends_the_apps_session(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut app = Client::new(&db);
    app.sign_in_app(&user).await;

    let response = app.post_without_body("/api/auth/logout").await;

    assert_eq!(response.status, StatusCode::NO_CONTENT);
    assert_eq!(app.get("/api/me").await.status, StatusCode::UNAUTHORIZED);
}

#[database_test]
async fn succeeds_when_signed_out_already(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db).post_without_body("/api/auth/logout").await;

    assert_eq!(response.status, StatusCode::NO_CONTENT);
}
