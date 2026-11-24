use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client, FakeServarr};

/// A folder that exists wherever the tests run
const FOLDER: &str = env!("CARGO_MANIFEST_DIR");

/// The ID of no Source
const MISSING_ID: &str = "01a1f26b-170d-75e6-b05d-1b3ceacf37a0";

/// Creates a Source with the configuration, and returns the URI of its imports.
async fn create(browser: &mut Client, configuration: serde_json::Value) -> String {
    let response = browser.post("/api/sources", configuration).await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    format!(
        "/api/sources/{}/media-imports",
        response.body["id"].as_str().unwrap()
    )
}

#[database_test]
async fn starts_an_import_of_a_radarr_source_that_waits_for_its_job(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;
    let uri = create(&mut browser, radarr.configuration()).await;

    let response = browser
        .post(&uri, json!({ "files_to_import": "new_and_unmatched" }))
        .await;

    assert_eq!(response.status, StatusCode::ACCEPTED, "{response:?}");
    let body = &response.body;
    assert!(body["id"].is_string());
    assert!(body["started_at"].is_string());
    assert_eq!(
        body,
        &json!({
            "id": body["id"],
            "trigger": "manual",
            "files_to_import": "new_and_unmatched",
            "state": "waiting",
            "failure": null,
            "file_count": null,
            "matched_file_count": 0,
            "unmatched_file_count": 0,
            "failed_file_count": 0,
            "removed_file_count": 0,
            "started_at": body["started_at"],
            "finished_at": null,
        })
    );
    assert_eq!(browser.get(&uri).await.body, json!([body]));
}

#[database_test]
async fn refuses_a_source_whose_type_doesnt_import_yet(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut browser = support::admin_browser(&db).await;
    let uri = create(
        &mut browser,
        json!({ "type": "filesystem", "media_type": "movie", "path": FOLDER }),
    )
    .await;

    let response = browser
        .post(&uri, json!({ "files_to_import": "all" }))
        .await;

    assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        response.body,
        json!({
            "code": "unsupported_source_type",
            "message": "the Source's type doesn't import yet",
        })
    );
}

#[database_test]
async fn answers_not_found_for_a_source_that_doesnt_exist(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut browser = support::admin_browser(&db).await;

    let response = browser
        .post(
            &format!("/api/sources/{MISSING_ID}/media-imports"),
            json!({ "files_to_import": "all" }),
        )
        .await;

    assert_eq!(response.status, StatusCode::NOT_FOUND);
    assert_eq!(
        response.body,
        json!({ "code": "not_found", "message": "no such Source" })
    );
}

#[database_test]
async fn refuses_a_choice_of_files_that_doesnt_exist(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;
    let uri = create(&mut browser, radarr.configuration()).await;

    let response = browser
        .post(&uri, json!({ "files_to_import": "some" }))
        .await;

    assert_eq!(response.status, StatusCode::BAD_REQUEST);
    assert_eq!(response.body["code"], "invalid_request");
}

#[database_test]
async fn refuses_users_other_than_the_instance_administrator(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut admin = support::admin_browser(&db).await;
    let uri = create(&mut admin, radarr.configuration()).await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);

    let request = json!({ "files_to_import": "all" });
    let signed_out = browser.post(&uri, request.clone()).await;
    browser.sign_in(&user).await;
    let signed_in = browser.post(&uri, request).await;

    assert_eq!(signed_out.status, StatusCode::UNAUTHORIZED);
    assert_eq!(signed_in.status, StatusCode::FORBIDDEN);
    assert_eq!(admin.get(&uri).await.body, json!([]));
}
