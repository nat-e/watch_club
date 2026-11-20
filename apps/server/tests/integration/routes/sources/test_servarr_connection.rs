use axum::http::StatusCode;
use serde_json::{Value, json};
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client, FakeServarr, fake_servarr::API_KEY};

/// A folder that exists wherever the tests run
const FOLDER: &str = env!("CARGO_MANIFEST_DIR");

/// The URI that tests the connection to a new Source's app
const URI: &str = "/api/sources/test-servarr-connection";

/// The URI that tests the connection to the app of no Source
const MISSING_SOURCE_URI: &str =
    "/api/sources/01a1f26b-170d-75e6-b05d-1b3ceacf37a0/test-servarr-connection";

/// Returns the body that tests the connection to a new Source's app.
fn connection(source_type: &str, url: &str, api_key: &str) -> Value {
    json!({ "type": source_type, "url": url, "api_key": api_key })
}

/// Creates a Source with this configuration, and returns the URI that tests the connection to its
/// app.
async fn create_source(browser: &mut Client, configuration: Value) -> String {
    let response = browser.post("/api/sources", configuration).await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    format!(
        "/api/sources/{}/test-servarr-connection",
        response.body["id"].as_str().unwrap()
    )
}

/// Returns the quality profiles and root folders of every fake app.
fn fake_apps_choices() -> Value {
    json!({
        "quality_profiles": [{ "id": 1, "name": "Any" }, { "id": 4, "name": "HD-1080p" }],
        "root_folders": ["/movies"],
    })
}

#[database_test]
async fn returns_the_quality_profiles_and_root_folders_of_a_new_sources_app(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;

    let response = browser
        .post(URI, connection("radarr", &radarr.url(), API_KEY))
        .await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body, fake_apps_choices());
}

#[database_test]
async fn returns_those_of_a_sources_app_with_its_saved_api_key(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;
    let uri = create_source(&mut browser, radarr.configuration()).await;

    let without_api_key = browser.post(&uri, json!({ "url": radarr.url() })).await;
    let with_null_api_key = browser
        .post(&uri, json!({ "url": radarr.url(), "api_key": null }))
        .await;

    for response in [without_api_key, with_null_api_key] {
        assert_eq!(response.status, StatusCode::OK, "{response:?}");
        assert_eq!(response.body, fake_apps_choices());
    }
}

#[database_test]
async fn returns_those_of_a_sources_app_with_the_api_key_in_the_body(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let moved_radarr = FakeServarr::radarr_with_api_key("new-api-key").await;
    let mut browser = support::admin_browser(&db).await;
    let uri = create_source(&mut browser, radarr.configuration()).await;

    let response = browser
        .post(
            &uri,
            json!({ "url": moved_radarr.url(), "api_key": "new-api-key" }),
        )
        .await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body, fake_apps_choices());
}

#[database_test]
async fn answers_why_watchclub_cant_call_the_app(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let sonarr = FakeServarr::sonarr().await;
    let mut browser = support::admin_browser(&db).await;
    let uri = create_source(&mut browser, radarr.configuration()).await;

    let wrong_key = browser
        .post(URI, connection("radarr", &radarr.url(), "wrong-key"))
        .await;
    let wrong_url = browser
        .post(URI, connection("radarr", &sonarr.url(), API_KEY))
        .await;
    let sources_wrong_url = browser.post(&uri, json!({ "url": sonarr.url() })).await;

    assert_eq!(wrong_key.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        wrong_key.body,
        json!({ "code": "invalid_api_key", "message": "there's no API key the app takes" })
    );
    for response in [wrong_url, sources_wrong_url] {
        assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(
            response.body,
            json!({
                "code": "invalid_servarr_url",
                "message": "the URL doesn't lead to the app's API",
            })
        );
    }
}

#[database_test]
async fn answers_not_found_for_sources_that_arent_apps(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut browser = support::admin_browser(&db).await;
    let filesystem_uri = create_source(
        &mut browser,
        json!({ "type": "filesystem", "media_type": "movie", "path": FOLDER }),
    )
    .await;

    for uri in [filesystem_uri.as_str(), MISSING_SOURCE_URI] {
        let response = browser
            .post(uri, json!({ "url": "http://radarr:7878" }))
            .await;

        assert_eq!(response.status, StatusCode::NOT_FOUND, "{uri}");
        assert_eq!(
            response.body,
            json!({ "code": "not_found", "message": "no such Radarr, Sonarr or Sportarr Source" }),
            "{uri}"
        );
    }
}

#[database_test]
async fn refuses_users_other_than_the_instance_administrator(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let radarr = FakeServarr::radarr().await;
    let mut browser = Client::new(&db);
    let request = connection("radarr", &radarr.url(), API_KEY);
    let source_request = json!({ "url": radarr.url() });

    let signed_out = browser.post(URI, request.clone()).await;
    let signed_out_to_source = browser
        .post(MISSING_SOURCE_URI, source_request.clone())
        .await;
    browser.sign_in(&user).await;
    let signed_in = browser.post(URI, request).await;
    let signed_in_to_source = browser.post(MISSING_SOURCE_URI, source_request).await;

    assert_eq!(signed_out.status, StatusCode::UNAUTHORIZED);
    assert_eq!(signed_out_to_source.status, StatusCode::UNAUTHORIZED);
    assert_eq!(signed_in.status, StatusCode::FORBIDDEN);
    assert_eq!(signed_in_to_source.status, StatusCode::FORBIDDEN);
    assert!(radarr.server.received_requests().await.unwrap().is_empty());
}
