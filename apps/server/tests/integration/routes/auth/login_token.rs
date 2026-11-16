use axum::http::{StatusCode, header::SET_COOKIE};
use serde_json::json;
use sqlx::PgPool;

use crate::support::{self, Client, PASSWORD};

#[sqlx::test]
async fn gives_the_app_a_token_that_signs_its_requests_in(db: PgPool) {
    let user = support::create_user(&db, "ada").await;
    let mut app = Client::new(&db);

    app.sign_in_app(&user).await;

    let me = app.get("/api/me").await;
    assert_eq!(me.status, StatusCode::OK);
    assert_eq!(me.body["username"], "ada");
}

#[sqlx::test]
async fn sets_no_cookie(db: PgPool) {
    support::create_user(&db, "ada").await;

    let credentials = json!({ "username": "ada", "password": PASSWORD });
    let response = Client::new(&db)
        .post("/api/auth/login/token", credentials)
        .await;

    assert_eq!(response.status, StatusCode::CREATED);
    assert!(!response.headers.contains_key(SET_COOKIE));
}

#[sqlx::test]
async fn refuses_wrong_credentials(db: PgPool) {
    support::create_user(&db, "ada").await;

    let credentials = json!({ "username": "ada", "password": "wrong password" });
    let response = Client::new(&db)
        .post("/api/auth/login/token", credentials)
        .await;

    assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(response.body["code"], "wrong_credentials");
}
