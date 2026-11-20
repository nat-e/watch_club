//! `Servarr`, the gateway to Radarr, Sonarr and Sportarr: the app it connects to, what it reads
//! from it, and which setting it blames when a call fails.

use serde_json::json;
use watch_club::domain::sources::{ConnectionError, QualityProfile, Servarr, ServarrApp};
use wiremock::{
    Mock, MockServer, ResponseTemplate,
    matchers::{method, path},
};

use super::request_count;
use crate::support::{
    self, FakeServarr,
    fake_servarr::{API_KEY, ROOT_FOLDER},
};

/// Connects to the app at `url` with this API key, encrypted with the tests' key.
async fn connect(app: ServarrApp, url: &str, api_key: &str) -> Result<Servarr, ConnectionError> {
    let encryption_key = support::encryption_key();
    let api_key = encryption_key.encrypt(&api_key.into());
    Servarr::connect(app, url, &api_key, &encryption_key, &support::http_client()).await
}

#[tokio::test]
async fn connects_to_each_app() {
    for (fake, app) in [
        (FakeServarr::radarr().await, ServarrApp::Radarr),
        (FakeServarr::sonarr().await, ServarrApp::Sonarr),
        (FakeServarr::sportarr().await, ServarrApp::Sportarr),
    ] {
        let result = connect(app, &fake.url(), API_KEY).await;

        assert!(result.is_ok(), "{app:?}: {result:?}");
    }
}

#[tokio::test]
async fn lists_the_apps_quality_profiles_and_root_folders() {
    let radarr = FakeServarr::radarr().await;
    let servarr = connect(ServarrApp::Radarr, &radarr.url(), API_KEY)
        .await
        .unwrap();

    let quality_profiles = servarr.list_quality_profiles().await.unwrap();
    let root_folders = servarr.list_root_folders().await.unwrap();

    assert_eq!(
        quality_profiles,
        [
            QualityProfile {
                id: 1,
                name: "Any".to_owned(),
            },
            QualityProfile {
                id: 4,
                name: "HD-1080p".to_owned(),
            },
        ]
    );
    assert_eq!(root_folders, [ROOT_FOLDER]);
}

#[tokio::test]
async fn calls_sportarr_through_its_own_api() {
    let sonarr = FakeServarr::sonarr().await;

    let result = connect(ServarrApp::Sportarr, &sonarr.url(), API_KEY).await;

    // Sonarr has no API at Sportarr's path
    assert_eq!(result.err(), Some(ConnectionError::InvalidServarrUrl));
}

#[tokio::test]
async fn calls_the_app_at_a_url_with_a_trailing_slash() {
    let radarr = FakeServarr::radarr().await;

    let result = connect(ServarrApp::Radarr, &format!("{}/", radarr.url()), API_KEY).await;

    assert!(result.is_ok(), "{result:?}");
}

#[tokio::test]
async fn calls_the_app_behind_a_reverse_proxy_at_a_path() {
    let proxy = MockServer::start().await;
    Mock::given(method("GET"))
        .and(path("/radarr/api/v3/system/status"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({ "appName": "Radarr" })))
        .mount(&proxy)
        .await;

    let url = format!("{}/radarr/", proxy.uri());
    let result = connect(ServarrApp::Radarr, &url, API_KEY).await;

    assert!(result.is_ok(), "{result:?}");
}

#[tokio::test]
async fn refuses_a_url_where_another_app_answers() {
    let sonarr = FakeServarr::sonarr().await;

    let result = connect(ServarrApp::Radarr, &sonarr.url(), API_KEY).await;

    assert_eq!(result.err(), Some(ConnectionError::InvalidServarrUrl));
}

// `utils::url` tests which URLs are http or https URLs
#[tokio::test]
async fn refuses_urls_that_arent_http_or_https() {
    let result = connect(ServarrApp::Radarr, "ftp://radarr", API_KEY).await;

    assert_eq!(result.err(), Some(ConnectionError::InvalidServarrUrl));
}

#[tokio::test]
async fn refuses_an_api_key_that_cant_go_in_a_request() {
    let result = connect(ServarrApp::Radarr, "http://radarr:7878", "line\nbreak").await;

    assert_eq!(result.err(), Some(ConnectionError::InvalidApiKey));
}

#[tokio::test]
async fn refuses_an_api_key_it_cant_decrypt_without_calling_the_app() {
    let radarr = FakeServarr::radarr().await;
    let encrypted = support::another_encryption_key().encrypt(&API_KEY.into());

    let result = Servarr::connect(
        ServarrApp::Radarr,
        &radarr.url(),
        &encrypted,
        &support::encryption_key(),
        &support::http_client(),
    )
    .await;

    assert_eq!(result.err(), Some(ConnectionError::InvalidApiKey));
    assert_eq!(request_count(&radarr).await, 0);
}

#[tokio::test]
async fn blames_the_api_key_when_the_app_rejects_it() {
    let radarr = FakeServarr::radarr().await;

    let result = connect(ServarrApp::Radarr, &radarr.url(), "wrong-key").await;

    assert_eq!(result.err(), Some(ConnectionError::InvalidApiKey));
}

#[tokio::test]
async fn blames_the_url_when_the_app_isnt_there() {
    // Answers 404 to every request, like a web server that isn't the app
    let elsewhere = MockServer::start().await;

    // Nothing listens on the first
    for url in ["http://127.0.0.1:1", &elsewhere.uri()] {
        let result = connect(ServarrApp::Radarr, url, API_KEY).await;

        assert_eq!(
            result.err(),
            Some(ConnectionError::InvalidServarrUrl),
            "{url}"
        );
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
        let result = connect(ServarrApp::Radarr, &server.uri(), API_KEY).await;

        assert_eq!(
            result.err(),
            Some(ConnectionError::InvalidServarrUrl),
            "{}",
            server.uri()
        );
    }
}
