use axum::http::StatusCode;
use serde_json::{Value, json};
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

fn preferences() -> Value {
    json!({
        "locale": "fr-FR",
        "audio_language": "en",
        "subtitle_language": null,
        "languages_without_subtitles": ["en", "fr"],
    })
}

#[database_test]
async fn saves_the_users_preferences(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    let response = browser.put("/api/me/preferences", preferences()).await;

    assert_eq!(response.status, StatusCode::OK);
    assert_eq!(response.body["preferences"], preferences());
    assert_eq!(
        browser.get("/api/me").await.body["preferences"],
        preferences()
    );
}

#[database_test]
async fn refuses_a_language_watchclub_does_not_have(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;

    for (field, language) in [
        ("locale", json!("de-DE")),
        ("audio_language", json!("de")),
        ("subtitle_language", json!("de")),
        ("languages_without_subtitles", json!(["de"])),
    ] {
        let mut body = preferences();
        body[field] = language;

        let response = browser.put("/api/me/preferences", body).await;

        assert_eq!(response.status, StatusCode::BAD_REQUEST, "{field}");
    }
}

#[database_test]
async fn refuses_preferences_without_the_subtitles(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    browser.sign_in(&user).await;
    let mut body = preferences();
    body.as_object_mut().unwrap().remove("subtitle_language");

    let response = browser.put("/api/me/preferences", body).await;

    assert_eq!(response.status, StatusCode::BAD_REQUEST);
}

#[database_test]
async fn refuses_requests_without_a_session(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let response = Client::new(&db)
        .put("/api/me/preferences", preferences())
        .await;

    assert_eq!(response.status, StatusCode::UNAUTHORIZED);
}
