use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club::domain::accounts::{self, Locale, UserPreferences};
use watch_club_test_macros::database_test;
use wiremock::{
    Mock, ResponseTemplate,
    matchers::{method, path, query_param},
};

use crate::support::{
    self, Client, FakeHardcover, FakeSportarr, FakeTmdb, fake_hardcover, fake_sportarr,
    fake_tmdb::fixture,
};

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
    let mut browser = Client::with_metadata_providers(&db, tmdb.metadata_providers());
    browser.sign_in(&user).await;

    let response = browser
        .get("/api/search?query=am%C3%A9lie&scope=movies_and_tv_shows&page=2")
        .await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body["next_page"], 3);
    let results = response.body["results"].as_array().unwrap();
    assert_eq!(results.len(), 5);
    assert_eq!(
        results[0],
        json!({
            "content_type": "movie",
            "external_id": "194",
            "title": "Amélie",
            "year": 2001,
            "overview": "At a tiny Parisian café, the adorable yet painfully shy Amélie accidentally \
                discovers a gift for helping others. Soon Amelie is spending her days as a \
                matchmaker, guardian angel, and all-around do-gooder. But when she bumps into a \
                handsome stranger, will she find the courage to become the star of her very own \
                love story?",
            "poster": [
                {"url": "https://image.tmdb.org/t/p/w92/nSxDa3M9aMvGVLoItzWTepQ5h5d.jpg", "width": 92, "height": 138},
                {"url": "https://image.tmdb.org/t/p/w154/nSxDa3M9aMvGVLoItzWTepQ5h5d.jpg", "width": 154, "height": 231},
                {"url": "https://image.tmdb.org/t/p/w185/nSxDa3M9aMvGVLoItzWTepQ5h5d.jpg", "width": 185, "height": 278},
                {"url": "https://image.tmdb.org/t/p/w342/nSxDa3M9aMvGVLoItzWTepQ5h5d.jpg", "width": 342, "height": 513},
                {"url": "https://image.tmdb.org/t/p/w500/nSxDa3M9aMvGVLoItzWTepQ5h5d.jpg", "width": 500, "height": 750},
                {"url": "https://image.tmdb.org/t/p/w780/nSxDa3M9aMvGVLoItzWTepQ5h5d.jpg", "width": 780, "height": 1170},
            ],
            "creators": [],
            "date": null,
            "league": null,
        })
    );
    assert_eq!(results[2].get("poster"), Some(&json!(null)));
    assert_eq!(results[4]["content_type"], "tv_show");
}

#[database_test]
async fn returns_a_page_of_books(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let hardcover = FakeHardcover::start().await;
    hardcover
        .answer("SearchBooks", fake_hardcover::fixture("search_books"))
        .await;
    let mut browser = Client::with_metadata_providers(&db, hardcover.metadata_providers());
    browser.sign_in(&user).await;

    let response = browser.get("/api/search?query=asterix&scope=books").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body["next_page"], 2);
    let results = response.body["results"].as_array().unwrap();
    assert_eq!(results.len(), 20);
    assert_eq!(
        results[2],
        json!({
            "content_type": "book",
            "external_id": "474596",
            "title": "Asterix and the Goths",
            "year": 1963,
            "overview": "Des espions Goths ont infiltré la Gaule afin de capturer le meilleur druide \
                lors de leur rencontre annuelle dans la forêt des Carnutes. C'est le druide \
                Panoramix qui gagne. à partir de 6 ans.",
            "poster": [{
                "url": "https://assets.hardcover.app/edition/30395786/981ce12c58007da620399643b2e27e9014c33423.jpeg",
                "width": 377,
                "height": 500,
            }],
            "creators": ["René Goscinny", "Albert Uderzo"],
            "date": null,
            "league": null,
        })
    );
}

#[database_test]
async fn returns_the_sports_events_on_one_page(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let sportarr = FakeSportarr::start().await;
    sportarr
        .answer(
            "/search/event/canelo%25berlanga",
            fake_sportarr::fixture("search_events"),
        )
        .await;
    let mut browser = Client::with_metadata_providers(&db, sportarr.metadata_providers());
    browser.sign_in(&user).await;

    let response = browser
        .get("/api/search?query=canelo%20berlanga&scope=sports_events")
        .await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body["next_page"], json!(null));
    let results = response.body["results"].as_array().unwrap();
    assert_eq!(results.len(), 18);
    assert_eq!(
        results[3],
        json!({
            "content_type": "sports_event",
            "external_id": "ev-575969",
            "title": "Canelo Álvarez vs Edgar Berlanga",
            "year": 2024,
            "overview": "Mexico locks horns with Puerto Rico once again, as 168lbs king Canelo \
                Alvarez (61-2-2) takes on Edgar Berlanga (22-0). With Alvarez putting his Super \
                middleweight titles on the line, can he extend his reign at the divisions summit?",
            "poster": [{
                "url": "https://sportarr.net/static/images/event/58/58ab0873-e360-4e8f-b6ea-eed1f9378de4/poster_thesportsdb_b6a5111271d5.jpg?v=g1-b6a5111271d5",
                "width": 680,
                "height": 1000,
            }],
            "creators": [],
            "date": "2024-09-15",
            "league": "Boxing",
        })
    );
}

#[database_test]
async fn refuses_a_search_without_a_scope(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser.get("/api/search?query=amelie").await;

    assert_eq!(response.status, StatusCode::BAD_REQUEST);
    assert_eq!(response.body["code"], "invalid_request");
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
    let mut browser = Client::with_metadata_providers(&db, tmdb.metadata_providers());
    browser.sign_in(&user).await;

    let response = browser
        .get("/api/search?query=amelie&scope=movies_and_tv_shows")
        .await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body["next_page"], 2);
}

#[database_test]
async fn refuses_a_page_below_1(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser
        .get("/api/search?query=amelie&scope=movies_and_tv_shows&page=0")
        .await;

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
    let mut browser = Client::with_metadata_providers(&db, tmdb.metadata_providers());
    browser.sign_in(&user).await;

    let response = browser
        .get("/api/search?query=amelie&scope=movies_and_tv_shows")
        .await;

    assert_eq!(response.status, StatusCode::INTERNAL_SERVER_ERROR);
    assert_eq!(response.body["code"], "internal_error");
}

#[database_test]
async fn refuses_requests_without_a_session(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db)
        .get("/api/search?query=amelie&scope=movies_and_tv_shows")
        .await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
