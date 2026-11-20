//! The errors of requests that no endpoint takes as they are: another path, another method, or a
//! body that isn't JSON or is too large. They have the body of every error response.

use axum::http::{StatusCode, header::ALLOW};
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::Client;

#[database_test]
async fn unknown_paths_say_so_rather_than_that_something_is_missing(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut client = Client::new(&db);

    for path in ["/api", "/api/", "/api/nothing-here"] {
        let response = client.get(path).await;

        assert_eq!(response.status, StatusCode::NOT_FOUND, "{path}");
        assert_eq!(response.body["code"], "unknown_endpoint", "{path}");
    }
}

#[database_test]
async fn another_method_is_not_allowed_and_the_allowed_ones_are_listed(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut client = Client::new(&db);

    for path in ["/api/me", "/api/health"] {
        let response = client.delete(path).await;

        assert_eq!(response.status, StatusCode::METHOD_NOT_ALLOWED, "{path}");
        assert_eq!(response.body["code"], "method_not_allowed", "{path}");
        assert_eq!(response.headers[ALLOW], "GET,HEAD", "{path}");
    }
}

#[database_test]
async fn a_body_that_is_not_json_is_an_unsupported_media_type(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db).post_without_body("/api/auth/login").await;

    assert_eq!(response.status, StatusCode::UNSUPPORTED_MEDIA_TYPE);
    assert_eq!(response.body["code"], "unsupported_media_type");
}

#[database_test]
async fn a_body_over_2_mb_is_too_large(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let credentials = json!({ "username": "a".repeat(3_000_000), "password": "secret" });
    let response = Client::new(&db).post("/api/auth/login", credentials).await;

    assert_eq!(response.status, StatusCode::PAYLOAD_TOO_LARGE);
    assert_eq!(response.body["code"], "payload_too_large");
}
