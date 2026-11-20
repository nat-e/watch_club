use axum::http::StatusCode;
use serde_json::{Value, json};
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client, FakeServarr};

/// Folders that exist wherever the tests run
const FOLDER: &str = env!("CARGO_MANIFEST_DIR");
const OTHER_FOLDER: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/src");

/// The ID of no Source
const MISSING_ID: &str = "01a1f26b-170d-75e6-b05d-1b3ceacf37a0";

/// Creates a Source with this configuration, and returns its ID.
async fn create(browser: &mut Client, configuration: Value) -> String {
    let response = browser.post("/api/sources", configuration).await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    response.body["id"].as_str().unwrap().to_owned()
}

#[database_test]
async fn answers_with_the_updated_source(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut browser = support::admin_browser(&db).await;
    let id = create(
        &mut browser,
        json!({ "type": "filesystem", "media_type": "movie", "path": FOLDER }),
    )
    .await;

    let response = browser
        .put(
            &format!("/api/sources/{id}"),
            json!({ "type": "filesystem", "media_type": "movie", "path": OTHER_FOLDER }),
        )
        .await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(
        response.body,
        json!({ "id": id, "type": "filesystem", "media_type": "movie", "path": OTHER_FOLDER })
    );
}

#[database_test]
async fn keeps_the_saved_api_key_when_the_body_leaves_it_out_or_sends_null(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;
    let id = create(&mut browser, radarr.configuration()).await;
    let saved = support::saved_api_key(&db, &id).await;
    let mut without_api_key = radarr.configuration();
    without_api_key.as_object_mut().unwrap().remove("api_key");
    let mut with_null_api_key = radarr.configuration();
    with_null_api_key["api_key"] = Value::Null;

    for configuration in [without_api_key, with_null_api_key] {
        let response = browser
            .put(&format!("/api/sources/{id}"), configuration)
            .await;

        // The fake app takes only its API key, which the body didn't send
        assert_eq!(response.status, StatusCode::OK, "{response:?}");
        assert_eq!(support::saved_api_key(&db, &id).await, saved);
    }
}

#[database_test]
async fn answers_why_the_source_cant_take_the_configuration(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut browser = support::admin_browser(&db).await;
    let id = create(
        &mut browser,
        json!({ "type": "filesystem", "media_type": "movie", "path": FOLDER }),
    )
    .await;

    let invalid = browser
        .put(
            &format!("/api/sources/{id}"),
            json!({ "type": "filesystem", "media_type": "movie", "path": "/no/such/folder" }),
        )
        .await;
    let other_type = browser
        .put(
            &format!("/api/sources/{id}"),
            json!({ "type": "filesystem", "media_type": "tv_show_episode", "path": FOLDER }),
        )
        .await;

    assert_eq!(invalid.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        invalid.body,
        json!({
            "code": "invalid_filesystem_configuration",
            "error": { "code": "not_found" },
            "message": "WatchClub can't read the folder",
        })
    );
    assert_eq!(other_type.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        other_type.body,
        json!({ "code": "type_changed", "message": "a Source keeps its type and Media Type" })
    );
}

#[database_test]
async fn answers_not_found_for_a_source_that_doesnt_exist(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut browser = support::admin_browser(&db).await;

    let response = browser
        .put(
            &format!("/api/sources/{MISSING_ID}"),
            json!({ "type": "filesystem", "media_type": "movie", "path": FOLDER }),
        )
        .await;

    assert_eq!(response.status, StatusCode::NOT_FOUND);
    assert_eq!(
        response.body,
        json!({ "code": "not_found", "message": "no such Source" })
    );
}

#[database_test]
async fn refuses_users_other_than_the_instance_administrator(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut admin = support::admin_browser(&db).await;
    let id = create(
        &mut admin,
        json!({ "type": "filesystem", "media_type": "movie", "path": FOLDER }),
    )
    .await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    let configuration =
        json!({ "type": "filesystem", "media_type": "movie", "path": OTHER_FOLDER });

    let signed_out = browser
        .put(&format!("/api/sources/{id}"), configuration.clone())
        .await;
    browser.sign_in(&user).await;
    let signed_in = browser
        .put(&format!("/api/sources/{id}"), configuration)
        .await;

    assert_eq!(signed_out.status, StatusCode::UNAUTHORIZED);
    assert_eq!(signed_in.status, StatusCode::FORBIDDEN);
    assert_eq!(admin.get("/api/sources").await.body[0]["path"], FOLDER);
}
