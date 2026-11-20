use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client, FakeServarr};

/// A folder that exists wherever the tests run
const FOLDER: &str = env!("CARGO_MANIFEST_DIR");

#[database_test]
async fn lists_each_source_with_its_type_and_without_its_api_key(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;
    let folder = browser
        .post(
            "/api/sources",
            json!({ "type": "filesystem", "media_type": "movie", "path": FOLDER }),
        )
        .await;
    let app = browser.post("/api/sources", radarr.configuration()).await;

    let response = browser.get("/api/sources").await;

    assert_eq!(response.status, StatusCode::OK, "{response:?}");
    assert_eq!(
        response.body,
        json!([
            {
                "id": folder.body["id"],
                "type": "filesystem",
                "media_type": "movie",
                "path": FOLDER,
            },
            {
                "id": app.body["id"],
                "type": "radarr",
                "media_type": "movie",
                "url": format!("{}/", radarr.url()),
                "quality_profile": { "id": 4, "name": "HD-1080p" },
                "root_folder_path": "/movies",
                "local_root_folder_path": null,
            },
        ])
    );
}

#[database_test]
async fn refuses_users_other_than_the_instance_administrator(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);

    let signed_out = browser.get("/api/sources").await;
    browser.sign_in(&user).await;
    let signed_in = browser.get("/api/sources").await;

    assert_eq!(signed_out.status, StatusCode::UNAUTHORIZED);
    assert_eq!(signed_in.status, StatusCode::FORBIDDEN);
}
