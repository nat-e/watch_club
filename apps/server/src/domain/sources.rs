//! Sources: where WatchClub imports Media Files from. A Filesystem Source is a folder on the
//! server; the others are a Radarr, Sonarr or Sportarr app, which downloads the Content its Source
//! requests. Only the Instance Administrator manages them.
//!
//! This module and its `store`, which saves the Sources in the database, are the only ones that
//! match on the Source Type. It hands each Source Configuration to its type's module, `filesystem`
//! or `servarr`, which validates it.

mod filesystem;
mod servarr;
mod store;

use std::fmt::{self, Display, Formatter};

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

pub use self::{
    filesystem::{FilesystemConfiguration, FilesystemConfigurationInput},
    servarr::{
        ConnectionError, QualityProfile, Servarr, ServarrApp, ServarrConfiguration,
        ServarrConfigurationError, ServarrConfigurationInput,
    },
};
use crate::{
    api_client::HttpClient,
    db::Pool,
    domain::{InternalError, contents::MediaType},
    utils::{
        encryption::{EncryptedSecret, EncryptionKey},
        filesystem::FolderError,
    },
};

/// The unique ID of a Source.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[sqlx(transparent)]
pub struct SourceId(Uuid);

impl Display for SourceId {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// The kind of place WatchClub imports Media Files from, as the `sources` table stores it. The
/// variant of a `SourceConfiguration` tells it everywhere else.
#[derive(Clone, Copy, Debug, PartialEq, Eq, sqlx::Type)]
#[sqlx(type_name = "source_type", rename_all = "snake_case")]
pub enum SourceType {
    Filesystem,
    Radarr,
    Sonarr,
    Sportarr,
}

impl SourceType {
    /// Returns the app that a Source of this type is, or None for a Filesystem Source.
    const fn app(self) -> Option<ServarrApp> {
        match self {
            Self::Filesystem => None,
            Self::Radarr => Some(ServarrApp::Radarr),
            Self::Sonarr => Some(ServarrApp::Sonarr),
            Self::Sportarr => Some(ServarrApp::Sportarr),
        }
    }
}

impl From<ServarrApp> for SourceType {
    fn from(app: ServarrApp) -> Self {
        match app {
            ServarrApp::Radarr => Self::Radarr,
            ServarrApp::Sonarr => Self::Sonarr,
            ServarrApp::Sportarr => Self::Sportarr,
        }
    }
}

/// A Source, with its Source Configuration.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Source {
    pub id: SourceId,
    pub configuration: SourceConfiguration,
}

/// The Source Configuration of a Source, which WatchClub validated: it can read its folders and
/// call its app with it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SourceConfiguration {
    Filesystem(FilesystemConfiguration),
    Servarr(ServarrConfiguration),
}

impl SourceConfiguration {
    /// Returns the Source Type this configuration is for.
    pub fn source_type(&self) -> SourceType {
        match self {
            Self::Filesystem(_) => SourceType::Filesystem,
            Self::Servarr(configuration) => configuration.app.into(),
        }
    }

    /// Returns the Media Type of the files the Source brings: the one a Filesystem Source was
    /// created with, or its app's.
    pub const fn media_type(&self) -> MediaType {
        match self {
            Self::Filesystem(configuration) => configuration.media_type,
            Self::Servarr(configuration) => configuration.app.media_type(),
        }
    }

    /// Returns the configuration to save, once its type's module validated it.
    async fn parse(
        configuration: ConfigurationInput,
        encryption_key: &EncryptionKey,
        http_client: &HttpClient,
    ) -> Result<Self, ConfigurationError> {
        match configuration {
            ConfigurationInput::Filesystem(configuration) => Ok(Self::Filesystem(
                FilesystemConfiguration::parse(configuration).await?,
            )),
            ConfigurationInput::Servarr(configuration) => Ok(Self::Servarr(
                ServarrConfiguration::parse(configuration, encryption_key, http_client).await?,
            )),
        }
    }
}

/// The Source Configuration the Instance Administrator enters, which `create` and `update`
/// validate.
#[derive(Debug)]
pub enum ConfigurationInput {
    Filesystem(FilesystemConfigurationInput),
    Servarr(ServarrConfigurationInput),
}

impl ConfigurationInput {
    /// Returns the Source Type this configuration is for, which `update` compares with the
    /// Source's.
    fn source_type(&self) -> SourceType {
        match self {
            Self::Filesystem(_) => SourceType::Filesystem,
            Self::Servarr(configuration) => configuration.app.into(),
        }
    }

    /// Returns the Media Type this configuration is for, which `update` compares with the Source's.
    const fn media_type(&self) -> MediaType {
        match self {
            Self::Filesystem(configuration) => configuration.media_type,
            Self::Servarr(configuration) => configuration.app.media_type(),
        }
    }
}

/// The error WatchClub found in the Source Configuration the Instance Administrator entered, which
/// depends on the Source Type.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum ConfigurationError {
    /// A Filesystem Source's folder
    #[error("the folder: {0}")]
    Filesystem(#[from] FolderError),
    #[error(transparent)]
    Servarr(#[from] ServarrConfigurationError),
}

/// The reason a Source wasn't created.
#[derive(Debug, thiserror::Error)]
pub enum CreateError {
    #[error("the configuration is invalid")]
    InvalidConfiguration(ConfigurationError),
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// The reason a Source wasn't updated.
#[derive(Debug, thiserror::Error)]
pub enum UpdateError {
    /// There's no Source with the ID, or it was deleted while WatchClub validated its new
    /// configuration
    #[error("no such Source")]
    SourceNotFound,
    /// The new configuration is for another Source Type or Media Type, which a Source keeps
    #[error("the Source's type or Media Type would change")]
    TypeChanged,
    #[error("the configuration is invalid")]
    InvalidConfiguration(ConfigurationError),
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// The reason a Source wasn't deleted.
#[derive(Debug, thiserror::Error)]
pub enum DeleteError {
    #[error("no such Source")]
    SourceNotFound,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// The reason WatchClub didn't check a Source's app.
#[derive(Debug, thiserror::Error)]
pub enum CheckExistingSourceError {
    /// There's no Source with the ID, or it's a Filesystem Source, which has no app
    #[error("no such Radarr, Sonarr or Sportarr Source")]
    SourceNotFound,
    #[error(transparent)]
    Connection(#[from] ConnectionError),
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Returns every Source, oldest first.
#[tracing::instrument(skip_all)]
pub async fn list(db: &Pool) -> Result<Vec<Source>, InternalError> {
    Ok(store::list(db).await?)
}

/// Validates the configuration, then creates a Source with it.
#[tracing::instrument(skip_all)]
pub async fn create(
    db: &Pool,
    configuration: ConfigurationInput,
    encryption_key: &EncryptionKey,
    http_client: &HttpClient,
) -> Result<Source, CreateError> {
    let configuration = SourceConfiguration::parse(configuration, encryption_key, http_client)
        .await
        .map_err(CreateError::InvalidConfiguration)?;

    Ok(store::insert(db, configuration).await?)
}

/// Validates the configuration, then gives it to the Source, which keeps its type and Media Type,
/// and its API key unless the configuration has another one.
#[tracing::instrument(skip_all, fields(source.id = %id))]
pub async fn update(
    db: &Pool,
    id: SourceId,
    mut configuration: ConfigurationInput,
    encryption_key: &EncryptionKey,
    http_client: &HttpClient,
) -> Result<Source, UpdateError> {
    let current = store::get_by_id(db, id)
        .await?
        .ok_or(UpdateError::SourceNotFound)?;
    let keeps_its_type = configuration.source_type() == current.configuration.source_type()
        && configuration.media_type() == current.configuration.media_type();
    if !keeps_its_type {
        return Err(UpdateError::TypeChanged);
    }

    // Keeps the saved API key, unless the configuration has another one
    if let (ConfigurationInput::Servarr(input), SourceConfiguration::Servarr(saved)) =
        (&mut configuration, current.configuration)
    {
        input.api_key.get_or_insert(saved.api_key);
    }
    let configuration = SourceConfiguration::parse(configuration, encryption_key, http_client)
        .await
        .map_err(UpdateError::InvalidConfiguration)?;

    // None when the Source was deleted while its configuration was validated
    store::update(db, id, configuration)
        .await?
        .ok_or(UpdateError::SourceNotFound)
}

/// Deletes the Source. Its files stay on disk.
#[tracing::instrument(skip_all, fields(source.id = %id))]
pub async fn delete(db: &Pool, id: SourceId) -> Result<(), DeleteError> {
    let was_there = store::delete(db, id).await?;

    if !was_there {
        return Err(DeleteError::SourceNotFound);
    }
    Ok(())
}

/// Returns the Source's app at `url`, once `Servarr::connect` checked that the app takes the API
/// key: the one entered, or else the Source's saved one.
#[tracing::instrument(skip_all, fields(source.id = %id))]
pub async fn check_existing_source(
    db: &Pool,
    id: SourceId,
    url: &str,
    api_key: Option<EncryptedSecret>,
    encryption_key: &EncryptionKey,
    http_client: &HttpClient,
) -> Result<Servarr, CheckExistingSourceError> {
    let source = store::get_by_id(db, id)
        .await?
        .ok_or(CheckExistingSourceError::SourceNotFound)?;
    let SourceConfiguration::Servarr(configuration) = source.configuration else {
        return Err(CheckExistingSourceError::SourceNotFound);
    };

    let api_key = api_key.unwrap_or(configuration.api_key);
    Ok(Servarr::connect(
        configuration.app,
        url,
        &api_key,
        encryption_key,
        http_client,
    )
    .await?)
}
