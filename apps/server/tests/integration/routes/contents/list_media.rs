use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client, FakeTmdb};

#[database_test]
async fn lists_the_episodes_of_a_tv_show_in_order(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;
    let mut browser = Client::with_metadata_providers(&db, tmdb.metadata_providers());
    browser.sign_in(&user).await;
    let tv_show = browser.get("/api/contents/tv_show/87108").await;
    let content_id = tv_show.body["id"].as_str().unwrap();

    let response = browser
        .get(&format!("/api/contents/{content_id}/media"))
        .await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    let episodes = response.body.as_array().unwrap();
    assert_eq!(episodes.len(), 5);
    let mut episode = episodes[0].clone();
    assert!(episode["id"].is_string(), "{episode}");
    assert_eq!(episode["image"][0]["width"], 92);
    for field in ["id", "image", "overview"] {
        episode.as_object_mut().unwrap().remove(field);
    }
    assert_eq!(
        episode,
        json!({
            "group_number": 1,
            "number_in_group": 1,
            "title": "1:23:45",
            "release_date": "2019-05-06",
            "runtime_seconds": 3660,
        })
    );
}

#[database_test]
async fn lists_nothing_for_a_content_that_isnt_saved(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser
        .get("/api/contents/01a1f51d-b4d0-7612-b428-7d695b6a08c4/media")
        .await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body, json!([]));
}

#[database_test]
async fn refuses_requests_without_a_session(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db)
        .get("/api/contents/01a1f51d-b4d0-7612-b428-7d695b6a08c4/media")
        .await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
