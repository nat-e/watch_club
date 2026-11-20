//! Radarr, Sonarr and Sportarr Sources: their app, their Source Configuration, which WatchClub
//! validates by calling the app with its API key, and `Servarr`, the gateway that calls the app.

use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use tracing::Level;
use utoipa::ToSchema;

use crate::{
    api_client::{ApiClient, ApiCredentials, ApiCredentialsError, CallError, HttpClient, Retries},
    domain::contents::MediaType,
    utils::{
        encryption::{EncryptedSecret, EncryptionKey},
        filesystem::{AbsoluteFolder, FolderError},
        url,
    },
};

/// One of the apps that a Source can be.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum ServarrApp {
    Radarr,
    Sonarr,
    Sportarr,
}

impl ServarrApp {
    /// Returns its name, as it calls itself.
    pub const fn name(self) -> &'static str {
        match self {
            Self::Radarr => "Radarr",
            Self::Sonarr => "Sonarr",
            Self::Sportarr => "Sportarr",
        }
    }

    /// Returns the Media Type of the files it downloads.
    pub const fn media_type(self) -> MediaType {
        match self {
            Self::Radarr => MediaType::Movie,
            Self::Sonarr => MediaType::TvShowEpisode,
            Self::Sportarr => MediaType::SportsEvent,
        }
    }

    /// Returns the segments of its API's path under its URL, such as `api/v3`. Sportarr's own API,
    /// rather than the copy of Sonarr's it also has, which says it's Sonarr.
    const fn api_path(self) -> &'static [&'static str] {
        match self {
            Self::Radarr | Self::Sonarr => &["api", "v3"],
            Self::Sportarr => &["api"],
        }
    }
}

/// A quality profile of an app: the quality it downloads requested Content in.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct QualityProfile {
    /// The app's ID of the profile
    pub id: i32,
    pub name: String,
}

/// The Source Configuration of a Radarr, Sonarr or Sportarr Source.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ServarrConfiguration {
    /// The app, which tells the Source Type and the Media Type
    pub app: ServarrApp,
    /// The address WatchClub calls the app at, without a trailing `/`
    pub url: String,
    /// The key WatchClub calls the app with, which it decrypts only to call it
    pub api_key: EncryptedSecret,
    /// The quality the app downloads requested Content in
    pub quality_profile: QualityProfile,
    /// The folder the app downloads requested Content to, as the app sees it
    pub root_folder_path: String,
    /// The root folder, as WatchClub sees it when that's another path, such as in Docker
    pub local_root_folder_path: Option<AbsoluteFolder>,
}

/// The Source Configuration the Instance Administrator enters for a Radarr, Sonarr or Sportarr
/// Source.
#[derive(Debug)]
pub struct ServarrConfigurationInput {
    pub app: ServarrApp,
    pub url: String,
    /// The API key the Instance Administrator entered, encrypted as soon as WatchClub received it,
    /// or None to keep the Source's saved one
    pub api_key: Option<EncryptedSecret>,
    /// The ID of one of the app's quality profiles
    pub quality_profile_id: i32,
    /// The path of one of the app's root folders
    pub root_folder_path: String,
    /// None or blank when WatchClub sees the root folder at the app's path
    pub local_root_folder_path: Option<String>,
}

/// The first error WatchClub found in the Source Configuration the Instance Administrator entered
/// for a Radarr, Sonarr or Sportarr Source: the part to change, and why.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "part", rename_all = "snake_case")]
pub enum ServarrConfigurationError {
    /// The app's URL or API key
    #[error(transparent)]
    Connection(#[from] ConnectionError),
    /// The app has no quality profile with the ID, such as one deleted in the app since the form
    /// listed it
    #[error("the app has no quality profile with this ID")]
    QualityProfile,
    /// The app has no root folder at the path, such as one deleted in the app since the form listed
    /// it
    #[error("the app has no root folder at this path")]
    RootFolder,
    #[error("the local root folder: {0}")]
    LocalRootFolder(FolderError),
}

/// The reason WatchClub can't use a Source's app: which of its URL and API key the Instance
/// Administrator has to change. The logs say why.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
pub enum ConnectionError {
    /// It isn't an http or https URL, nothing answers there, or what answers isn't the app the
    /// Source expects, or answers with an error
    #[error("the URL doesn't lead to the app's API")]
    InvalidServarrUrl,
    /// There's none, WatchClub can't decrypt the saved one, or the app rejects it
    #[error("there's no API key the app takes")]
    InvalidApiKey,
}

impl ServarrConfiguration {
    /// Returns the configuration to save, with its URL tidied, once `AbsoluteFolder::parse` found
    /// the local root folder, `Servarr::connect` checked the app, and the app has the quality
    /// profile and root folder. Checks the local root folder first, which doesn't call the app.
    pub(super) async fn parse(
        configuration: ServarrConfigurationInput,
        encryption_key: &EncryptionKey,
        http_client: &HttpClient,
    ) -> Result<Self, ServarrConfigurationError> {
        let ServarrConfigurationInput {
            app,
            url,
            api_key,
            quality_profile_id,
            root_folder_path,
            local_root_folder_path,
        } = configuration;

        let local_root_folder_path = match local_root_folder_path.as_deref().map(str::trim) {
            Some(path) if !path.is_empty() => Some(
                AbsoluteFolder::parse(path)
                    .await
                    .map_err(ServarrConfigurationError::LocalRootFolder)?,
            ),
            _ => None,
        };

        let api_key = api_key.ok_or(ConnectionError::InvalidApiKey)?;
        let url = url::tidy_http_url(&url).ok_or(ConnectionError::InvalidServarrUrl)?;
        let servarr = Servarr::connect(app, &url, &api_key, encryption_key, http_client).await?;
        let (quality_profiles, root_folders) =
            tokio::try_join!(servarr.list_quality_profiles(), servarr.list_root_folders())?;

        // The app has the quality profile and root folder
        let quality_profile = quality_profiles
            .into_iter()
            .find(|profile| profile.id == quality_profile_id)
            .ok_or(ServarrConfigurationError::QualityProfile)?;
        if !root_folders.contains(&root_folder_path) {
            return Err(ServarrConfigurationError::RootFolder);
        }

        Ok(Self {
            app,
            url,
            api_key,
            quality_profile,
            root_folder_path,
            local_root_folder_path,
        })
    }
}

/// The gateway to a Radarr, Sonarr or Sportarr app: the app at a Source's URL, which answered,
/// took the API key and is the app the Source expects.
#[derive(Debug)]
pub struct Servarr {
    app: ServarrApp,
    /// Calls the app once, without retries: the Instance Administrator waits for the answer, which
    /// retries would delay when the URL is wrong
    api: ApiClient,
}

impl Servarr {
    /// Returns the app at `url`, an http or https URL, once it checked that the app takes the API
    /// key, which it decrypts only to call the app, and that it's `app`, rather than Sonarr at a
    /// Radarr Source's URL for example. Doesn't call the app when it can't decrypt the API key.
    pub async fn connect(
        app: ServarrApp,
        url: &str,
        api_key: &EncryptedSecret,
        encryption_key: &EncryptionKey,
        http_client: &HttpClient,
    ) -> Result<Self, ConnectionError> {
        let api_key = encryption_key.decrypt(api_key).map_err(|error| {
            tracing::event!(
                name: "sources.api_key.unreadable",
                Level::WARN,
                exception.message = %error,
                "failed to decrypt a Source's API key",
            );
            // The Instance Administrator enters it again
            ConnectionError::InvalidApiKey
        })?;

        let mut api_url = url::parse_http_url(url).ok_or(ConnectionError::InvalidServarrUrl)?;
        api_url
            .path_segments_mut()
            .expect("an http URL can have paths")
            .pop_if_empty()
            .extend(app.api_path());
        let credentials = ApiCredentials::api_key(&api_key)?;
        let api = ApiClient::new(http_client, api_url, credentials, Retries::Never);
        let servarr = Self { app, api };

        let app_name = servarr.fetch_app_name().await?;
        if app_name != app.name() {
            tracing::event!(
                name: "servarr.app.unexpected",
                Level::WARN,
                servarr.app = app.name(),
                exception.message = %format_args!("{app_name} answered, rather than {}", app.name()),
                "another app answered at a Source's URL",
            );
            return Err(ConnectionError::InvalidServarrUrl);
        }

        Ok(servarr)
    }

    /// Returns the app's quality profiles.
    #[tracing::instrument(skip_all, fields(servarr.app = self.app.name()))]
    pub async fn list_quality_profiles(&self) -> Result<Vec<QualityProfile>, ConnectionError> {
        self.api
            .get("/qualityprofile", &[], &[])
            .await?
            .ok_or_else(|| answered_not_found("GET /qualityprofile"))
    }

    /// Returns the paths of the app's root folders, as it sees them, such as `/movies`.
    #[tracing::instrument(skip_all, fields(servarr.app = self.app.name()))]
    pub async fn list_root_folders(&self) -> Result<Vec<String>, ConnectionError> {
        let root_folders: Vec<RootFolder> = self
            .api
            .get("/rootfolder", &[], &[])
            .await?
            .ok_or_else(|| answered_not_found("GET /rootfolder"))?;
        Ok(root_folders.into_iter().map(|folder| folder.path).collect())
    }

    /// Returns the name the app gives itself, such as `Radarr`.
    #[tracing::instrument(skip_all, fields(servarr.app = self.app.name()))]
    async fn fetch_app_name(&self) -> Result<String, ConnectionError> {
        let status: SystemStatus = self
            .api
            .get("/system/status", &[], &[])
            .await?
            .ok_or_else(|| answered_not_found("GET /system/status"))?;

        status.app_name.ok_or_else(|| {
            tracing::event!(
                name: "servarr.call.failed",
                Level::WARN,
                exception.message = "the app's status has no name",
                "failed to call a Source's app",
            );
            ConnectionError::InvalidServarrUrl
        })
    }
}

/// Blames the API key when it has a character that can't go in a request, such as a line break.
impl From<ApiCredentialsError> for ConnectionError {
    fn from(_: ApiCredentialsError) -> Self {
        Self::InvalidApiKey
    }
}

/// Tells which setting a failed call shows is wrong: the API key when the app rejects it with a
/// 401, or else the URL. Logs the cause, which the Instance Administrator doesn't see.
impl From<CallError> for ConnectionError {
    fn from(error: CallError) -> Self {
        tracing::event!(
            name: "servarr.call.failed",
            Level::WARN,
            exception.message = %format_args!("{error:#}"),
            "failed to call a Source's app",
        );
        match error {
            CallError::Failed { status, .. } if status == StatusCode::UNAUTHORIZED => {
                Self::InvalidApiKey
            }
            // Nothing answered, or not as the app's API does, such as a web page or an error
            CallError::Unreachable { .. }
            | CallError::Failed { .. }
            | CallError::InvalidAnswer { .. } => Self::InvalidServarrUrl,
        }
    }
}

/// Returns the error of a call that the app answered with 404, as something other than its API
/// does, and logs it.
fn answered_not_found(call: &str) -> ConnectionError {
    tracing::event!(
        name: "servarr.call.failed",
        Level::WARN,
        exception.message = %format_args!("the app answered {call} with 404 Not Found"),
        "failed to call a Source's app",
    );
    ConnectionError::InvalidServarrUrl
}

/// An app's description of itself, from `GET /system/status`.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SystemStatus {
    /// Such as `Radarr`. None when what answered isn't one of the apps
    app_name: Option<String>,
}

/// A folder an app downloads Content to, from `GET /rootfolder`.
#[derive(Deserialize)]
struct RootFolder {
    path: String,
}
