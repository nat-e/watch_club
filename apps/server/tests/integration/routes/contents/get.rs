use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{
    self, Client, FakeHardcover, FakeSportarr, FakeTmdb, fake_hardcover, fake_sportarr,
};

#[database_test]
async fn returns_a_movie_in_the_users_locale(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;
    let mut browser = Client::with_metadata_providers(&db, tmdb.metadata_providers());
    browser.sign_in(&user).await;

    let response = browser.get("/api/contents/movie/194").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    let mut body = response.body;
    assert!(body["id"].is_string(), "{body}");
    assert_eq!(body["poster"][0]["width"], 92);
    assert_eq!(body["backdrop"][0]["width"], 300);
    assert_eq!(body["credits"][0]["photo"][0]["width"], 45);
    for field in ["id", "poster", "backdrop", "overview"] {
        body.as_object_mut().unwrap().remove(field);
    }
    body["credits"].as_array_mut().unwrap().truncate(2);
    for credit in body["credits"].as_array_mut().unwrap() {
        credit.as_object_mut().unwrap().remove("photo");
    }
    assert_eq!(
        body,
        json!({
            "content_type": "movie",
            "external_id": "194",
            "title": "Amélie",
            "original_title": "Le Fabuleux Destin d'Amélie Poulain",
            "original_language": "fr",
            "release_date": "2001-04-25",
            "genres": ["comedy", "romance"],
            "rating": 7.9,
            "trailer_url": "https://www.youtube.com/watch?v=j0aotpJRPgc",
            "credits": [
                {"kind": "director", "name": "Jean-Pierre Jeunet", "character": null},
                {"kind": "actor", "name": "Audrey Tautou", "character": "Amélie Poulain"},
            ],
            "runtime_seconds": 7320,
            "media_group_count": 0,
        })
    );
}

#[database_test]
async fn returns_a_tv_show_with_its_number_of_seasons(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;
    let mut browser = Client::with_metadata_providers(&db, tmdb.metadata_providers());
    browser.sign_in(&user).await;

    let response = browser.get("/api/contents/tv_show/87108").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body["title"], "Chernobyl");
    assert_eq!(response.body["media_group_count"], 1);
    assert_eq!(response.body["runtime_seconds"], json!(null));
}

#[database_test]
async fn returns_a_sports_event(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let sportarr = FakeSportarr::start().await;
    sportarr
        .answer("/lookup/event/ev-575969", fake_sportarr::fixture("event"))
        .await;
    let mut browser = Client::with_metadata_providers(&db, sportarr.metadata_providers());
    browser.sign_in(&user).await;

    let response = browser.get("/api/contents/sports_event/ev-575969").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body["content_type"], "sports_event");
    assert_eq!(response.body["external_id"], "ev-575969");
    assert_eq!(response.body["title"], "Canelo Álvarez vs Edgar Berlanga");
}

#[database_test]
async fn returns_a_book(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let hardcover = FakeHardcover::start().await;
    hardcover
        .answer("Book", fake_hardcover::fixture("book"))
        .await;
    let mut browser = Client::with_metadata_providers(&db, hardcover.metadata_providers());
    browser.sign_in(&user).await;

    let response = browser.get("/api/contents/book/442623").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body["content_type"], "book");
    assert_eq!(response.body["external_id"], "442623");
    assert_eq!(response.body["title"], "Asterix the Gaul");
}

#[database_test]
async fn returns_a_saved_content_when_tmdb_is_down(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;
    let mut browser = Client::with_metadata_providers(&db, tmdb.metadata_providers());
    browser.sign_in(&user).await;
    let saved = browser.get("/api/contents/movie/194").await;
    let mut browser_without_tmdb = Client::new(&db);
    browser_without_tmdb.sign_in(&user).await;

    let response = browser_without_tmdb.get("/api/contents/movie/194").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body, saved.body);
}

#[database_test]
async fn fails_when_tmdb_has_no_such_content(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    // Answers 404 to every request
    let tmdb = FakeTmdb::start().await;
    let mut browser = Client::with_metadata_providers(&db, tmdb.metadata_providers());
    browser.sign_in(&user).await;

    let response = browser.get("/api/contents/movie/194").await;

    assert_eq!(response.status, StatusCode::NOT_FOUND);
    assert_eq!(
        response.body,
        json!({"code": "not_found", "message": "no such Content"})
    );
}

#[database_test]
async fn fails_when_tmdb_is_down_and_nothing_is_saved(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser.get("/api/contents/movie/194").await;

    assert_eq!(response.status, StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(response.body["code"], "internal_error");
}

#[database_test]
async fn fails_when_the_id_cant_be_one_of_the_metadata_provider(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let tmdb = FakeTmdb::start().await;
    let mut browser = Client::with_metadata_providers(&db, tmdb.metadata_providers());
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

    let response = browser.get("/api/contents/podcast/194").await;

    assert_eq!(response.status, StatusCode::BAD_REQUEST);
    assert_eq!(response.body["code"], "invalid_request");
}

#[database_test]
async fn refuses_requests_without_a_session(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db).get("/api/contents/movie/194").await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
