//! The client of Radarr's, Sonarr's and Sportarr's APIs, which have the same calls to set up a
//! Source, and of the calls each app has for its own files. It calls the app as told: its callers
//! decide what its failures mean.

use secrecy::SecretString;
use serde::Deserialize;

use super::{QualityProfile, ServarrApp};
use crate::api_client::{ApiClient, ApiCredentials, ApiCredentialsError, ApiUrl, HttpClient};

/// A client of the API of a Radarr, Sonarr or Sportarr app.
#[derive(Debug)]
pub(super) struct ServarrClient {
    api: ApiClient,
}

impl ServarrClient {
    /// Returns a client of the API of `app` at `url`, the app's address, which calls it with the API
    /// key. Makes no call.
    pub(super) fn new(
        http_client: &HttpClient,
        app: ServarrApp,
        url: &ApiUrl,
        api_key: &SecretString,
    ) -> Result<Self, ApiCredentialsError> {
        let credentials = ApiCredentials::api_key(api_key)?;

        Ok(Self {
            api: ApiClient::new(http_client, url.join(app.api_path()), credentials),
        })
    }

    /// Returns the name the app gives itself, such as `Radarr`.
    pub(super) async fn fetch_app_name(&self) -> Result<String, reqwest::Error> {
        let status: SystemStatus = self.api.get_required("/system/status", &[], &[]).await?;
        Ok(status.app_name)
    }

    /// Returns the app's quality profiles.
    pub(super) async fn list_quality_profiles(
        &self,
    ) -> Result<Vec<QualityProfile>, reqwest::Error> {
        self.api.get_required("/qualityprofile", &[], &[]).await
    }

    /// Returns the paths of the app's root folders, as it sees them, such as `/movies`.
    pub(super) async fn list_root_folders(&self) -> Result<Vec<String>, reqwest::Error> {
        let root_folders: Vec<RootFolder> = self.api.get_required("/rootfolder", &[], &[]).await?;
        Ok(root_folders.into_iter().map(|folder| folder.path).collect())
    }

    /// Returns every Movie of a Radarr app, with its file if it has one. Radarr lists them all at
    /// once, without pages.
    pub(super) async fn list_movies(&self) -> Result<Vec<RadarrMovie>, reqwest::Error> {
        // Without the covers it would otherwise look up on its disk for each Movie, which slows the
        // answer of large libraries
        self.api
            .get_required("/movie", &[], &[("excludeLocalCovers", "true")])
            .await
    }
}

/// An app's description of itself, from `GET /system/status`.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SystemStatus {
    /// Such as `Radarr`
    app_name: String,
}

/// A folder an app downloads Content to, from `GET /rootfolder`.
#[derive(Deserialize)]
struct RootFolder {
    path: String,
}

/// A Movie in Radarr, from `GET /movie`.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct RadarrMovie {
    pub tmdb_id: u32,
    /// Empty, or missing, when Radarr doesn't know it
    #[serde(default)]
    pub imdb_id: Option<String>,
    pub quality_profile_id: i32,
    /// Its file, when Radarr has one
    pub movie_file: Option<RadarrMovieFile>,
}

/// The file of a Movie in Radarr.
#[derive(Deserialize)]
pub(super) struct RadarrMovieFile {
    /// Where Radarr sees it
    pub path: String,
}
