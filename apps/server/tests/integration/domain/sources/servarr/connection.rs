//! `servarr::test_connection`, which tests the connection to Radarr, Sonarr and Sportarr: the app
//! it reaches, what it reads from it, and which setting it blames when a call fails. And
//! `servarr::test_saved_connection`, which tests it with a Source's saved API key.

use serde_json::json;
use watch_club::domain::sources::servarr::{
    self, QualityProfile, ServarrApp, ServarrChoices, TestConnectionError,
};
use wiremock::{
    Mock, MockServer, ResponseTemplate,
    matchers::{method, path},
};

use crate::support::{
    self, FakeServarr,
    fake_servarr::{API_KEY, ROOT_FOLDER},
};

/// Tests the connection to the app at `url` with this API key.
async fn test_connection(
    app: ServarrApp,
    url: &str,
    api_key: &str,
) -> Result<ServarrChoices, TestConnectionError> {
    servarr::test_connection(&support::http_client(), app, url, &api_key.into()).await
}

#[tokio::test]
async fn reaches_each_app() {
    for (fake, app) in [
        (FakeServarr::radarr().await, ServarrApp::Radarr),
        (FakeServarr::sonarr().await, ServarrApp::Sonarr),
        (FakeServarr::sportarr().await, ServarrApp::Sportarr),
    ] {
        let result = test_connection(app, &fake.url(), API_KEY).await;

        assert!(result.is_ok(), "{app:?}: {result:?}");
    }
}

#[tokio::test]
async fn returns_the_apps_quality_profiles_and_root_folders() {
    let radarr = FakeServarr::radarr().await;

    let choices = test_connection(ServarrApp::Radarr, &radarr.url(), API_KEY)
        .await
        .unwrap();

    assert_eq!(
        choices,
        ServarrChoices {
            quality_profiles: vec![
                QualityProfile {
                    id: 1,
                    name: "Any".to_owned(),
                },
                QualityProfile {
                    id: 4,
                    name: "HD-1080p".to_owned(),
                },
            ],
            root_folders: vec![ROOT_FOLDER.to_owned()],
        }
    );
}

#[tokio::test]
async fn calls_sportarr_through_its_own_api() {
    let sonarr = FakeServarr::sonarr().await;

    let result = test_connection(ServarrApp::Sportarr, &sonarr.url(), API_KEY).await;

    // Sonarr has no API at Sportarr's path
    assert_eq!(result.err(), Some(TestConnectionError::InvalidUrl));
}

#[tokio::test]
async fn calls_the_app_at_a_url_with_a_trailing_slash() {
    let radarr = FakeServarr::radarr().await;

    let result = test_connection(ServarrApp::Radarr, &format!("{}/", radarr.url()), API_KEY).await;

    assert!(result.is_ok(), "{result:?}");
}

#[tokio::test]
async fn calls_the_app_behind_a_reverse_proxy_at_a_path() {
    let proxy = MockServer::start().await;
    for (route, body) in [
        ("system/status", json!({ "appName": "Radarr" })),
        ("qualityprofile", json!([])),
        ("rootfolder", json!([])),
    ] {
        Mock::given(method("GET"))
            .and(path(format!("/radarr/api/v3/{route}")))
            .respond_with(ResponseTemplate::new(200).set_body_json(body))
            .mount(&proxy)
            .await;
    }

    let url = format!("{}/radarr/", proxy.uri());
    let result = test_connection(ServarrApp::Radarr, &url, API_KEY).await;

    assert!(result.is_ok(), "{result:?}");
}

#[tokio::test]
async fn refuses_a_url_where_another_app_answers() {
    let sonarr = FakeServarr::sonarr().await;

    let result = test_connection(ServarrApp::Radarr, &sonarr.url(), API_KEY).await;

    assert_eq!(result.err(), Some(TestConnectionError::InvalidUrl));
}

#[tokio::test]
async fn refuses_urls_it_cant_call() {
    // Without `http://`, `radarr` is the scheme of a URL that can't have a path
    for url in ["radarr:7878", "ftp://radarr"] {
        let result = test_connection(ServarrApp::Radarr, url, API_KEY).await;

        assert_eq!(result.err(), Some(TestConnectionError::InvalidUrl), "{url}");
    }
}

#[tokio::test]
async fn refuses_an_api_key_that_cant_go_in_a_request() {
    let result = test_connection(ServarrApp::Radarr, "http://radarr:7878", "line\nbreak").await;

    assert_eq!(result.err(), Some(TestConnectionError::InvalidApiKey));
}

#[tokio::test]
async fn blames_the_api_key_when_the_app_rejects_it() {
    let radarr = FakeServarr::radarr().await;

    let result = test_connection(ServarrApp::Radarr, &radarr.url(), "wrong-key").await;

    assert_eq!(result.err(), Some(TestConnectionError::InvalidApiKey));
}

#[tokio::test]
async fn blames_the_url_when_the_app_isnt_there() {
    // Answers 404 to every request, like a web server that isn't the app
    let elsewhere = MockServer::start().await;

    // Nothing listens on the first
    for url in ["http://127.0.0.1:1", &elsewhere.uri()] {
        let result = test_connection(ServarrApp::Radarr, url, API_KEY).await;

        assert_eq!(result.err(), Some(TestConnectionError::InvalidUrl), "{url}");
    }
}

#[tokio::test]
async fn blames_the_url_when_what_answers_isnt_one_of_the_apps() {
    let nameless = MockServer::start().await;
    Mock::given(method("GET"))
        .and(path("/api/v3/system/status"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({ "version": "1.0.0" })))
        .mount(&nameless)
        .await;
    let failing = MockServer::start().await;
    Mock::given(method("GET"))
        .respond_with(ResponseTemplate::new(500))
        .mount(&failing)
        .await;

    for server in [nameless, failing] {
        let result = test_connection(ServarrApp::Radarr, &server.uri(), API_KEY).await;

        assert_eq!(
            result.err(),
            Some(TestConnectionError::InvalidUrl),
            "{}",
            server.uri()
        );
    }
}

mod test_saved_connection {
    use sqlx::PgPool;
    use watch_club::{
        db::Pool,
        domain::sources::{
            SourceId,
            servarr::{ServarrChoices, TestSavedConnectionError},
        },
        utils::encryption::EncryptionKey,
    };
    use watch_club_test_macros::database_test;

    use super::*;
    use crate::domain::sources::{
        FOLDER, create_app_source, create_movies_folder, deleted_source_id,
    };

    /// Tests the connection to the Source's app at `url`, with this API key, or else its saved one,
    /// which `encryption_key` decrypts.
    async fn test_saved_connection(
        db: &Pool,
        encryption_key: &EncryptionKey,
        id: SourceId,
        url: &str,
        api_key: Option<&str>,
    ) -> Result<ServarrChoices, TestSavedConnectionError> {
        servarr::test_saved_connection(
            db,
            encryption_key,
            &support::http_client(),
            id,
            url,
            api_key.map(Into::into),
        )
        .await
    }

    #[database_test]
    async fn uses_the_saved_api_key_without_another(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_app_source(&db, &radarr).await;

        let result = test_saved_connection(
            &db,
            &support::encryption_key(),
            source.id(),
            &radarr.url(),
            None,
        )
        .await;

        assert!(result.is_ok(), "{result:?}");
    }

    #[database_test]
    async fn uses_the_api_key_it_gets_rather_than_the_saved_one(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_app_source(&db, &radarr).await;

        let result = test_saved_connection(
            &db,
            &support::encryption_key(),
            source.id(),
            &radarr.url(),
            Some("wrong-key"),
        )
        .await;

        assert!(
            matches!(
                result,
                Err(TestSavedConnectionError::Connection(
                    TestConnectionError::InvalidApiKey
                ))
            ),
            "{result:?}"
        );
    }

    #[database_test]
    async fn blames_the_api_key_when_another_key_encrypted_it(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_app_source(&db, &radarr).await;

        let result = test_saved_connection(
            &db,
            &support::another_encryption_key(),
            source.id(),
            &radarr.url(),
            None,
        )
        .await;

        assert!(
            matches!(
                result,
                Err(TestSavedConnectionError::Connection(
                    TestConnectionError::InvalidApiKey
                ))
            ),
            "{result:?}"
        );
    }

    #[database_test]
    async fn is_not_found_for_a_folder_or_a_deleted_source(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let folder = create_movies_folder(&db, FOLDER).await;
        let deleted = deleted_source_id(&db).await;

        for id in [folder.id(), deleted] {
            let result =
                test_saved_connection(&db, &support::encryption_key(), id, &radarr.url(), None)
                    .await;

            assert!(
                matches!(result, Err(TestSavedConnectionError::NotFound)),
                "{result:?}"
            );
        }
    }
}
