//! Radarr, Sonarr and Sportarr Sources: their app, their Source Configuration, creating and updating
//! them, and the connection test that checks the app at a URL takes an API key and lists the
//! quality profiles and root folders the Instance Administrator chooses from. `client` calls the
//! app.

mod client;

use anyhow::Context;
use reqwest::StatusCode;
use secrecy::SecretString;
use serde::{Deserialize, Serialize};
use sqlx_otel::QueryAnnotateExt;
use tracing::Level;
use utoipa::ToSchema;

use self::client::ServarrClient;
use super::{Source, SourceConfiguration, SourceId, SourceType, UpdateError};
use crate::{
    api_client::{ApiCredentialsError, ApiUrl, ApiUrlError, HttpClient},
    db::Pool,
    domain::contents::MediaType,
    utils::{
        encryption::{EncryptedSecret, EncryptionKey},
        filesystem::AbsoluteFolder,
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
    /// The address WatchClub calls the app at, with its API under it
    pub url: ApiUrl,
    /// The key WatchClub calls the app with, which it decrypts only to call it
    pub api_key: EncryptedSecret,
    /// The quality the app downloads requested Content in
    pub quality_profile: QualityProfile,
    /// The folder the app downloads requested Content to, as the app sees it
    pub root_folder_path: String,
    /// The root folder, as WatchClub sees it when that's another path, such as in Docker
    pub local_root_folder_path: Option<AbsoluteFolder>,
}

impl ServarrConfiguration {
    /// Returns the API key, decrypted to call the app. Refuses it when another key encrypted it,
    /// such as before the host changed `ENCRYPTION_KEY`: the Instance Administrator enters it again.
    pub fn decrypt_api_key(
        &self,
        encryption_key: &EncryptionKey,
    ) -> Result<SecretString, ConnectionError> {
        encryption_key.decrypt(&self.api_key).map_err(|error| {
            tracing::event!(
                name: "sources.api_key.unreadable",
                Level::WARN,
                exception.message = %error,
                "failed to decrypt a Source's API key",
            );
            ConnectionError::InvalidApiKey
        })
    }
}

/// The new Source Configuration of a Radarr, Sonarr or Sportarr Source, which keeps its app.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ServarrConfigurationUpdate {
    /// The address WatchClub calls the app at, with its API under it
    pub url: ApiUrl,
    /// A new key to call the app with, or None to keep the saved one
    pub api_key: Option<EncryptedSecret>,
    /// The quality the app downloads requested Content in
    pub quality_profile: QualityProfile,
    /// The folder the app downloads requested Content to, as the app sees it
    pub root_folder_path: String,
    /// The root folder, as WatchClub sees it when that's another path, such as in Docker
    pub local_root_folder_path: Option<AbsoluteFolder>,
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

/// The quality profiles and root folders of a Radarr, Sonarr or Sportarr app, which the Instance
/// Administrator chooses a Source's from.
#[derive(Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct ServarrChoices {
    pub quality_profiles: Vec<QualityProfile>,
    /// The paths of its root folders, as it sees them, such as `/movies`
    pub root_folders: Vec<String>,
}

/// Creates a Source of the configuration's app, and returns it.
#[tracing::instrument(skip_all, fields(servarr.app = configuration.app.name()))]
pub async fn create_servarr_source(
    db: &Pool,
    configuration: ServarrConfiguration,
) -> anyhow::Result<Source> {
    let id = sqlx::query_scalar!(
        r#"
        INSERT INTO sources (
            source_type, media_type, url, api_key_encrypted, quality_profile_id,
            quality_profile_name, root_folder_path, local_root_folder_path
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING id
        "#,
        SourceType::from(configuration.app),
        configuration.app.media_type(),
        configuration.url.as_str(),
        &configuration.api_key as &EncryptedSecret,
        configuration.quality_profile.id,
        configuration.quality_profile.name,
        configuration.root_folder_path,
        configuration.local_root_folder_path.as_ref() as Option<&AbsoluteFolder>,
    )
    .with_operation("INSERT", "sources")
    .fetch_one(db)
    .await
    .context("failed to create the app's Source")?;

    Ok(Source {
        id,
        configuration: SourceConfiguration::Servarr(configuration),
    })
}

/// Gives the Radarr, Sonarr or Sportarr Source with this ID the configuration, and returns it. The
/// Source keeps its app.
#[tracing::instrument(skip_all, fields(source.id = %id))]
pub async fn update_servarr_source(
    db: &Pool,
    id: SourceId,
    configuration: ServarrConfigurationUpdate,
) -> Result<Source, UpdateError> {
    // Without a new API key, `COALESCE` keeps the one in the row as it is when Postgres writes it,
    // rather than the one the caller read before: a key that another request saved meanwhile stays
    let updated = sqlx::query!(
        r#"
        UPDATE sources
        SET url = $2,
            api_key_encrypted = COALESCE($3, api_key_encrypted),
            quality_profile_id = $4,
            quality_profile_name = $5,
            root_folder_path = $6,
            local_root_folder_path = $7
        WHERE id = $1 AND source_type IN ('radarr', 'sonarr', 'sportarr')
        RETURNING source_type, api_key_encrypted AS "api_key_encrypted!: EncryptedSecret"
        "#,
        id as SourceId,
        configuration.url.as_str(),
        configuration.api_key.as_ref() as Option<&EncryptedSecret>,
        configuration.quality_profile.id,
        configuration.quality_profile.name,
        configuration.root_folder_path,
        configuration.local_root_folder_path.as_ref() as Option<&AbsoluteFolder>,
    )
    .with_operation("UPDATE", "sources")
    .fetch_optional(db)
    .await
    .context("failed to update the app's Source")?
    .ok_or(UpdateError::SourceNotFound)?;

    Ok(Source {
        id,
        configuration: SourceConfiguration::Servarr(ServarrConfiguration {
            app: updated
                .source_type
                .app()
                .expect("the update only finds apps' Sources"),
            url: configuration.url,
            api_key: updated.api_key_encrypted,
            quality_profile: configuration.quality_profile,
            root_folder_path: configuration.root_folder_path,
            local_root_folder_path: configuration.local_root_folder_path,
        }),
    })
}

/// Checks that `app` answers at `url` and takes the API key, then returns the app's quality
/// profiles and root folders. Refuses another app, such as Sonarr at a Radarr Source's URL.
#[tracing::instrument(skip_all, fields(servarr.app = app.name()))]
pub async fn test_servarr_connection(
    app: ServarrApp,
    url: &str,
    api_key: &SecretString,
    http_client: &HttpClient,
) -> Result<ServarrChoices, ConnectionError> {
    let url: ApiUrl = url.parse()?;
    let client = ServarrClient::new(http_client, app, &url, api_key)?;

    let app_name = client.fetch_app_name().await?;
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

    let (quality_profiles, root_folders) =
        tokio::try_join!(client.list_quality_profiles(), client.list_root_folders())?;
    Ok(ServarrChoices {
        quality_profiles,
        root_folders,
    })
}

/// Blames the URL when it isn't one WatchClub can call the app's API under, such as `radarr:7878`
/// without `http://`.
impl From<ApiUrlError> for ConnectionError {
    fn from(_: ApiUrlError) -> Self {
        Self::InvalidServarrUrl
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
impl From<reqwest::Error> for ConnectionError {
    fn from(error: reqwest::Error) -> Self {
        tracing::event!(
            name: "servarr.call.failed",
            Level::WARN,
            exception.message = %format_args!("{error:#}"),
            "failed to call a Source's app",
        );
        if error.status() == Some(StatusCode::UNAUTHORIZED) {
            Self::InvalidApiKey
        } else {
            // Nothing answered, or not as the app's API does, such as a web page, an error or a
            // 404 at the app's API path
            Self::InvalidServarrUrl
        }
    }
}
