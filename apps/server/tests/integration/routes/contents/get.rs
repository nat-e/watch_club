use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client, FakeTmdb, fake_tmdb::fixture};

#[database_test]
async fn returns_a_movie(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let tmdb = FakeTmdb::start().await;
    tmdb.answer("/movie/194", fixture("movie_details")).await;
    let mut browser = Client::with_tmdb(&db, tmdb.client());
    browser.sign_in(&user).await;

    let response = browser.get("/api/contents/movie/194").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(
        response.body,
        json!({
            "content_type": "movie",
            "external_id": "194",
            "title": "Le Fabuleux Destin d'Amélie Poulain",
        })
    );
}

#[database_test]
async fn returns_a_tv_show(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let tmdb = FakeTmdb::start().await;
    tmdb.answer("/tv/2316", fixture("tv_details")).await;
    let mut browser = Client::with_tmdb(&db, tmdb.client());
    browser.sign_in(&user).await;

    let response = browser.get("/api/contents/tv_show/2316").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body["title"], "The Office");
}

#[database_test]
async fn fails_when_tmdb_has_no_such_content(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    // Answers 404 to every request
    let tmdb = FakeTmdb::start().await;
    let mut browser = Client::with_tmdb(&db, tmdb.client());
    browser.sign_in(&user).await;

    let response = browser.get("/api/contents/movie/194").await;

    assert_eq!(response.status, StatusCode::NOT_FOUND);
    assert_eq!(
        response.body,
        json!({"code": "not_found", "message": "no such Content"})
    );
}

#[database_test]
async fn fails_when_the_id_cant_be_one_of_the_metadata_provider(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let tmdb = FakeTmdb::start().await;
    let mut browser = Client::with_tmdb(&db, tmdb.client());
    browser.sign_in(&user).await;

    let response = browser.get("/api/contents/movie/amelie").await;

    assert_eq!(response.status, StatusCode::NOT_FOUND);
    assert_eq!(response.body["code"], "not_found");
    assert!(tmdb.server.received_requests().await.unwrap().is_empty());
}

#[database_test]
async fn refuses_an_unknown_type_of_content(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser.get("/api/contents/book/194").await;

    assert_eq!(response.status, StatusCode::BAD_REQUEST);
    assert_eq!(response.body["code"], "invalid_request");
}

#[database_test]
async fn refuses_requests_without_a_session(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db).get("/api/contents/movie/194").await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
