use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club::domain::accounts::{self, Locale, UserPreferences};
use watch_club_test_macros::database_test;
use wiremock::{
    Mock, ResponseTemplate,
    matchers::{method, path, query_param},
};

use crate::support::{self, Client, FakeTmdb, fake_tmdb::fixture};

#[database_test]
async fn returns_a_page_of_movies_and_tv_shows_in_the_users_language(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    accounts::save_preferences(&db, user.id, &UserPreferences::new(Locale::FrFr))
        .await
        .unwrap();
    let tmdb = FakeTmdb::start().await;
    let mut page_2 = fixture("search_multi");
    page_2["page"] = json!(2);
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .and(query_param("query", "amélie"))
        .and(query_param("page", "2"))
        .and(query_param("language", "fr-FR"))
        .respond_with(ResponseTemplate::new(200).set_body_json(page_2))
        .expect(1)
        .mount(&tmdb.server)
        .await;
    let mut browser = Client::with_tmdb(&db, tmdb.client());
    browser.sign_in(&user).await;

    let response = browser.get("/api/search?query=am%C3%A9lie&page=2").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body["next_page"], 3);
    let results = response.body["results"].as_array().unwrap();
    assert_eq!(results.len(), 5);
    assert_eq!(
        results[0],
        json!({
            "content_type": "movie",
            "tmdb_id": 194,
            "title": "Amélie",
            "year": 2001,
            "overview": "At a tiny Parisian café, the adorable yet painfully shy Amélie accidentally \
                discovers a gift for helping others. Soon Amelie is spending her days as a \
                matchmaker, guardian angel, and all-around do-gooder. But when she bumps into a \
                handsome stranger, will she find the courage to become the star of her very own \
                love story?",
            "poster_path": "/nSxDa3M9aMvGVLoItzWTepQ5h5d.jpg",
        })
    );
    assert_eq!(results[4]["content_type"], "tv_show");
}

#[database_test]
async fn returns_the_first_page_by_default(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .and(query_param("page", "1"))
        .and(query_param("language", "en-US"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("search_multi")))
        .expect(1)
        .mount(&tmdb.server)
        .await;
    let mut browser = Client::with_tmdb(&db, tmdb.client());
    browser.sign_in(&user).await;

    let response = browser.get("/api/search?query=amelie").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body["next_page"], 2);
}

#[database_test]
async fn refuses_a_page_below_1(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser.get("/api/search?query=amelie&page=0").await;

    assert_eq!(response.status, StatusCode::BAD_REQUEST);
    assert_eq!(response.body["code"], "invalid_request");
}

#[database_test]
async fn fails_when_tmdb_does(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .respond_with(ResponseTemplate::new(500))
        .mount(&tmdb.server)
        .await;
    let mut browser = Client::with_tmdb(&db, tmdb.client());
    browser.sign_in(&user).await;

    let response = browser.get("/api/search?query=amelie").await;

    assert_eq!(response.status, StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(response.body["code"], "internal_error");
}

#[database_test]
async fn refuses_requests_without_a_session(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db).get("/api/search?query=amelie").await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
