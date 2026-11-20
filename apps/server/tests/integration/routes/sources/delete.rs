use axum::http::StatusCode;
use serde_json::{Value, json};
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client};

/// A folder that exists wherever the tests run
const FOLDER: &str = env!("CARGO_MANIFEST_DIR");

/// The ID of no Source
const MISSING_ID: &str = "01a1f26b-170d-75e6-b05d-1b3ceacf37a0";

/// Creates a Filesystem Source, and returns its URI.
async fn create(browser: &mut Client) -> String {
    let response = browser
        .post(
            "/api/sources",
            json!({ "type": "filesystem", "media_type": "movie", "path": FOLDER }),
        )
        .await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    format!("/api/sources/{}", response.body["id"].as_str().unwrap())
}

#[database_test]
async fn deletes_the_source(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut browser = support::admin_browser(&db).await;
    let uri = create(&mut browser).await;

    let response = browser.delete(&uri).await;

    assert_eq!(response.status, StatusCode::NO_CONTENT, "{response:?}");
    assert_eq!(response.body, Value::Null);
    assert_eq!(browser.get("/api/sources").await.body, json!([]));
}

#[database_test]
async fn answers_not_found_for_a_source_that_doesnt_exist(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut browser = support::admin_browser(&db).await;

    let response = browser.delete(&format!("/api/sources/{MISSING_ID}")).await;

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
    let uri = create(&mut admin).await;
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);

    let signed_out = browser.delete(&uri).await;
    browser.sign_in(&user).await;
    let signed_in = browser.delete(&uri).await;

    assert_eq!(signed_out.status, StatusCode::UNAUTHORIZED);
    assert_eq!(signed_in.status, StatusCode::FORBIDDEN);
    assert_eq!(
        admin
            .get("/api/sources")
            .await
            .body
            .as_array()
            .unwrap()
            .len(),
        1
    );
}
