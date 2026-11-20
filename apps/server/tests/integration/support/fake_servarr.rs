//! A fake Radarr, Sonarr or Sportarr app, which answers the calls that setting up a Source makes.

use serde_json::{Value, json};
use watch_club::domain::sources::{QualityProfile, ServarrApp, ServarrConfiguration};
use wiremock::{
    Mock, MockServer, Request, ResponseTemplate,
    matchers::{header, method, path},
};

/// The API key a fake app takes, unless it starts with another. It answers 401 to the others, and
/// 404 to the paths it doesn't have
pub const API_KEY: &str = "servarr-api-key";

/// The root folder a fake app downloads to
pub const ROOT_FOLDER: &str = "/movies";

/// An app with two quality profiles, `Any` (1) and `HD-1080p` (4), and one root folder,
/// `ROOT_FOLDER`.
pub struct FakeServarr {
    pub server: MockServer,
    /// The app it fakes, which tells the type of its Sources
    app: ServarrApp,
    /// The only API key it takes
    api_key: &'static str,
}

impl FakeServarr {
    pub async fn radarr() -> Self {
        Self::radarr_with_api_key(API_KEY).await
    }

    /// Starts a Radarr that takes only this API key.
    pub async fn radarr_with_api_key(api_key: &'static str) -> Self {
        Self::start(ServarrApp::Radarr, "Radarr", "/api/v3", api_key).await
    }

    pub async fn sonarr() -> Self {
        Self::start(ServarrApp::Sonarr, "Sonarr", "/api/v3", API_KEY).await
    }

    /// Starts a Sportarr, with its own API. It doesn't copy Sonarr's, as the real one also does.
    pub async fn sportarr() -> Self {
        Self::start(ServarrApp::Sportarr, "Sportarr", "/api", API_KEY).await
    }

    /// Starts an app that calls itself `name`, whose API is at `api_path`.
    async fn start(app: ServarrApp, name: &str, api_path: &str, api_key: &'static str) -> Self {
        let server = MockServer::start().await;
        let answers = [
            (
                "system/status",
                json!({ "appName": name, "version": "1.0.0" }),
            ),
            (
                "qualityprofile",
                json!([{ "id": 1, "name": "Any" }, { "id": 4, "name": "HD-1080p" }]),
            ),
            (
                "rootfolder",
                json!([{ "id": 1, "path": ROOT_FOLDER, "accessible": true }]),
            ),
        ];
        for (route, body) in answers {
            Mock::given(method("GET"))
                .and(path(format!("{api_path}/{route}")))
                .and(header("x-api-key", api_key))
                .respond_with(ResponseTemplate::new(200).set_body_json(body))
                .mount(&server)
                .await;
        }
        let has_another_key = move |request: &Request| {
            request
                .headers
                .get("x-api-key")
                .is_none_or(|key| key != api_key)
        };
        Mock::given(has_another_key)
            .respond_with(ResponseTemplate::new(401))
            .mount(&server)
            .await;
        Self {
            server,
            app,
            api_key,
        }
    }

    pub fn url(&self) -> String {
        self.server.uri()
    }

    /// Returns the Source Configuration of a Source of this app, with its API key and its `HD-1080p` profile.
    pub fn configuration(&self) -> Value {
        json!({
            "type": self.app,
            "url": self.url(),
            "api_key": self.api_key,
            "quality_profile": { "id": 4, "name": "HD-1080p" },
            "root_folder_path": ROOT_FOLDER,
            "local_root_folder_path": null,
        })
    }

    /// Returns the same Source Configuration as `configuration`, as `domain::sources` saves it,
    /// with its API key encrypted with the tests' key.
    pub fn source_configuration(&self) -> ServarrConfiguration {
        ServarrConfiguration {
            app: self.app,
            url: self.url().parse().unwrap(),
            api_key: super::encryption_key().encrypt(&self.api_key.into()),
            quality_profile: QualityProfile {
                id: 4,
                name: "HD-1080p".to_owned(),
            },
            root_folder_path: ROOT_FOLDER.to_owned(),
            local_root_folder_path: None,
        }
    }
}
