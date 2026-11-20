use axum::http::StatusCode;
use secrecy::ExposeSecret;
use serde_json::json;
use sqlx::PgPool;
use watch_club_test_macros::database_test;

use crate::support::{self, Client, FakeServarr, fake_servarr::API_KEY};

/// A folder that exists wherever the tests run
const FOLDER: &str = env!("CARGO_MANIFEST_DIR");

#[database_test]
async fn answers_with_the_created_source(db: PgPool) {
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

    assert_eq!(folder.status, StatusCode::CREATED, "{folder:?}");
    assert!(folder.body["id"].is_string(), "{folder:?}");
    assert_eq!(
        folder.body,
        json!({
            "id": folder.body["id"],
            "type": "filesystem",
            "media_type": "movie",
            "path": FOLDER,
        })
    );
    assert_eq!(app.status, StatusCode::CREATED, "{app:?}");
    assert_eq!(
        app.body,
        json!({
            "id": app.body["id"],
            "type": "radarr",
            "media_type": "movie",
            "url": radarr.url(),
            "quality_profile": { "id": 4, "name": "HD-1080p" },
            "root_folder_path": "/movies",
            "local_root_folder_path": null,
        })
    );
}

#[database_test]
async fn saves_the_api_key_encrypted_with_the_servers_key(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;

    let response = browser.post("/api/sources", radarr.configuration()).await;

    let id = response.body["id"].as_str().unwrap();
    let saved = support::saved_api_key(&db, id).await;
    let decrypted = support::encryption_key().decrypt(&saved).unwrap();
    assert_eq!(decrypted.expose_secret(), API_KEY);
}

#[database_test]
async fn answers_why_the_configuration_is_invalid(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;
    let mut configuration = radarr.configuration();
    configuration["root_folder_path"] = json!("/tv");

    let response = browser.post("/api/sources", configuration).await;

    assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        response.body,
        json!({
            "code": "invalid_servarr_configuration",
            "error": { "part": "root_folder" },
            "message": "WatchClub can't use the app with this configuration",
        })
    );
    assert_eq!(browser.get("/api/sources").await.body, json!([]));
}

#[database_test]
async fn refuses_a_body_that_isnt_a_configuration(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;
    // Required even though it can be null, so that leaving it out doesn't clear it
    let mut without_local_root_folder = radarr.configuration();
    without_local_root_folder
        .as_object_mut()
        .unwrap()
        .remove("local_root_folder_path");

    for body in [
        without_local_root_folder,
        json!({ "type": "filesystem", "media_type": "ebook", "path": FOLDER }),
        json!({ "type": "plex", "url": "http://plex:32400" }),
    ] {
        let response = browser.post("/api/sources", body.clone()).await;

        assert_eq!(response.status, StatusCode::BAD_REQUEST, "{body}");
    }
    assert_eq!(browser.get("/api/sources").await.body, json!([]));
}

#[database_test]
async fn refuses_users_other_than_the_instance_administrator(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let mut browser = Client::new(&db);
    let configuration = json!({ "type": "filesystem", "media_type": "movie", "path": FOLDER });

    let signed_out = browser.post("/api/sources", configuration.clone()).await;
    browser.sign_in(&user).await;
    let signed_in = browser.post("/api/sources", configuration).await;

    assert_eq!(signed_out.status, StatusCode::UNAUTHORIZED);
    assert_eq!(signed_in.status, StatusCode::FORBIDDEN);
}
