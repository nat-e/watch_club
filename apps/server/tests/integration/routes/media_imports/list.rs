use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client, FakeServarr};

/// The ID of no Source
const MISSING_ID: &str = "01a1f26b-170d-75e6-b05d-1b3ceacf37a0";

#[database_test]
async fn lists_the_imports_of_the_source_the_latest_first(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;
    let source = browser.post("/api/sources", radarr.configuration()).await;
    let other_source = browser.post("/api/sources", radarr.configuration()).await;
    let uri = format!(
        "/api/sources/{}/media-imports",
        source.body["id"].as_str().unwrap()
    );
    let first = browser
        .post(&uri, json!({ "files_to_import": "all" }))
        .await;
    let second = browser
        .post(&uri, json!({ "files_to_import": "new" }))
        .await;
    let other_uri = format!(
        "/api/sources/{}/media-imports",
        other_source.body["id"].as_str().unwrap()
    );
    browser
        .post(&other_uri, json!({ "files_to_import": "all" }))
        .await;

    let response = browser.get(&uri).await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(response.body, json!([second.body, first.body]));
}

#[database_test]
async fn lists_none_for_a_source_that_doesnt_exist(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut browser = support::admin_browser(&db).await;

    let response = browser
        .get(&format!("/api/sources/{MISSING_ID}/media-imports"))
        .await;

    assert_eq!(response.status, StatusCode::OK);
    assert_eq!(response.body, json!([]));
}

#[database_test]
async fn refuses_users_other_than_the_instance_administrator(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    let uri = format!("/api/sources/{MISSING_ID}/media-imports");

    let signed_out = browser.get(&uri).await;
    browser.sign_in(&user).await;
    let signed_in = browser.get(&uri).await;

    assert_eq!(signed_out.status, StatusCode::UNAUTHORIZED);
    assert_eq!(signed_in.status, StatusCode::FORBIDDEN);
}
