//! Sources: where WatchClub imports Media Files from. A Filesystem Source is a folder on the
//! server; the others are a Radarr, Sonarr or Sportarr app, which downloads the Content its Source
//! requests. Only the Instance Administrator manages them.
//!
//! This module and its `store`, which saves the Sources in the database, list, create and delete
//! every Source Type's Sources. Each type's module, `filesystem` or `servarr`, validates its Source
//! Configurations and updates its Sources. `servarr` also tests the connection to Radarr, Sonarr
//! and Sportarr apps.

mod filesystem;
mod servarr;
mod store;

use std::fmt::{self, Display, Formatter};

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

pub use self::{
    filesystem::{FilesystemConfiguration, FilesystemConfigurationInput, update_filesystem_source},
    servarr::{
        ConnectionError, QualityProfile, ServarrApp, ServarrChoices, ServarrConfiguration,
        ServarrConfigurationError, ServarrConfigurationInput, ServarrConfigurationUpdate,
        test_servarr_connection, update_servarr_source,
    },
};
use crate::{
    db::Pool,
    domain::{InternalError, contents::MediaType},
    utils::filesystem::FolderError,
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
    async fn validate(configuration: ConfigurationInput) -> Result<Self, ConfigurationError> {
        match configuration {
            ConfigurationInput::Filesystem(configuration) => Ok(Self::Filesystem(
                FilesystemConfiguration::validate(configuration).await?,
            )),
            ConfigurationInput::Servarr(configuration) => Ok(Self::Servarr(
                ServarrConfiguration::validate(configuration).await?,
            )),
        }
    }
}

/// The Source Configuration the Instance Administrator enters, which `create` validates.
#[derive(Debug)]
pub enum ConfigurationInput {
    Filesystem(FilesystemConfigurationInput),
    Servarr(ServarrConfigurationInput),
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
    /// There's no Source of the type with the ID, such as one deleted meanwhile
    #[error("no such Source")]
    SourceNotFound,
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

/// Returns every Source, oldest first.
#[tracing::instrument(skip_all)]
pub async fn list(db: &Pool) -> Result<Vec<Source>, InternalError> {
    Ok(store::list(db).await?)
}

/// Returns the Source with this ID, or None when there's none.
#[tracing::instrument(skip_all, fields(source.id = %id))]
pub async fn get(db: &Pool, id: SourceId) -> Result<Option<Source>, InternalError> {
    Ok(store::get_by_id(db, id).await?)
}

/// Validates the configuration, then creates a Source with it.
#[tracing::instrument(skip_all)]
pub async fn create(db: &Pool, configuration: ConfigurationInput) -> Result<Source, CreateError> {
    let configuration = SourceConfiguration::validate(configuration)
        .await
        .map_err(CreateError::InvalidConfiguration)?;

    Ok(store::insert(db, configuration).await?)
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
