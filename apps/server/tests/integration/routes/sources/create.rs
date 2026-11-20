use axum::http::StatusCode;
use secrecy::ExposeSecret;
use serde_json::{Value, json};
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
            "url": format!("{}/", radarr.url()),
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
async fn tidies_the_paths_and_the_url(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;
    let mut configuration = radarr.configuration();
    configuration["url"] = json!(format!(" {}/ ", radarr.url()));
    configuration["local_root_folder_path"] = json!(format!(" {FOLDER}/ "));

    let folder = browser
        .post(
            "/api/sources",
            json!({ "type": "filesystem", "media_type": "movie", "path": format!(" {FOLDER}/ ") }),
        )
        .await;
    let app = browser.post("/api/sources", configuration).await;

    assert_eq!(folder.status, StatusCode::CREATED, "{folder:?}");
    assert_eq!(folder.body["path"], FOLDER);
    assert_eq!(app.status, StatusCode::CREATED, "{app:?}");
    assert_eq!(app.body["url"], format!("{}/", radarr.url()));
    assert_eq!(app.body["local_root_folder_path"], FOLDER);
}

#[database_test]
async fn leaves_out_a_blank_local_root_folder(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;
    let mut configuration = radarr.configuration();
    configuration["local_root_folder_path"] = json!("  ");

    let response = browser.post("/api/sources", configuration).await;

    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    assert_eq!(response.body["local_root_folder_path"], Value::Null);
}

#[database_test]
async fn answers_why_the_configuration_is_invalid(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let mut browser = support::admin_browser(&db).await;
    let mut without_api_key = radarr.configuration();
    without_api_key["api_key"] = Value::Null;
    // Without `http://`, `radarr` is the URL's scheme
    let mut url_without_path = radarr.configuration();
    url_without_path["url"] = json!("radarr:7878");
    let mut missing_local_root_folder = radarr.configuration();
    missing_local_root_folder["local_root_folder_path"] = json!("/no/such/folder");
    let app_error = |error: Value| {
        json!({
            "code": "invalid_servarr_configuration",
            "error": error,
            "message": "the app's configuration is invalid",
        })
    };

    // `utils::filesystem` tests which paths lead to a folder
    for (configuration, expected) in [
        (
            json!({ "type": "filesystem", "media_type": "movie", "path": "/no/such/folder" }),
            json!({
                "code": "invalid_filesystem_configuration",
                "error": { "code": "not_found" },
                "message": "WatchClub can't read the folder",
            }),
        ),
        (
            without_api_key,
            app_error(json!({ "part": "connection", "code": "invalid_api_key" })),
        ),
        (
            url_without_path,
            app_error(json!({ "part": "connection", "code": "invalid_servarr_url" })),
        ),
        (
            missing_local_root_folder,
            app_error(json!({ "part": "local_root_folder", "code": "not_found" })),
        ),
    ] {
        let response = browser.post("/api/sources", configuration).await;

        assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(response.body, expected);
    }
    assert_eq!(browser.get("/api/sources").await.body, json!([]));
    // The connection test checked the app before
    assert_eq!(radarr.server.received_requests().await.unwrap().len(), 0);
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
