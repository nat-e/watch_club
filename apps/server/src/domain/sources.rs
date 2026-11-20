//! Sources: where WatchClub imports Media Files from. A Filesystem Source is a folder on the
//! server; the others are a Radarr, Sonarr or Sportarr app, which downloads the Content its Source
//! requests. Only the Instance Administrator manages them.
//!
//! This module lists, finds and deletes the Sources of every Source Type. Each type's module,
//! `filesystem` or `servarr`, creates and updates its own. `servarr` also tests the connection to
//! Radarr, Sonarr and Sportarr apps. The `sources` table has a column for each Source
//! Configuration's setting: each Source Type fills its own, which the table's constraints check.

mod filesystem;
mod servarr;

use std::fmt::{self, Display, Formatter};

use anyhow::Context;
use serde::{Deserialize, Serialize};
use sqlx_otel::QueryAnnotateExt;
use utoipa::ToSchema;
use uuid::Uuid;

pub use self::{
    filesystem::{FilesystemConfiguration, create_filesystem_source, update_filesystem_source},
    servarr::{
        ConnectionError, QualityProfile, ServarrApp, ServarrChoices, ServarrConfiguration,
        ServarrConfigurationUpdate, create_servarr_source, test_servarr_connection,
        update_servarr_source,
    },
};
use crate::{
    db::Pool,
    domain::{InternalError, contents::MediaType},
    utils::{encryption::EncryptedSecret, filesystem::AbsoluteFolder},
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
    let rows = sqlx::query_as!(
        SourceRow,
        r#"
        SELECT id, source_type, media_type, path, url, api_key_encrypted,
            quality_profile_id, quality_profile_name, root_folder_path, local_root_folder_path
        FROM sources
        ORDER BY inserted_at, id
        "#
    )
    .with_operation("SELECT", "sources")
    .fetch_all(db)
    .await
    .context("failed to list the Sources")?;

    Ok(rows.into_iter().map(SourceRow::into_source).collect())
}

/// Returns the Source with this ID, or None when there's none.
#[tracing::instrument(skip_all, fields(source.id = %id))]
pub async fn get(db: &Pool, id: SourceId) -> Result<Option<Source>, InternalError> {
    let row = sqlx::query_as!(
        SourceRow,
        r#"
        SELECT id, source_type, media_type, path, url, api_key_encrypted,
            quality_profile_id, quality_profile_name, root_folder_path, local_root_folder_path
        FROM sources
        WHERE id = $1
        "#,
        id as SourceId,
    )
    .with_operation("SELECT", "sources")
    .fetch_optional(db)
    .await
    .context("failed to find the Source")?;

    Ok(row.map(SourceRow::into_source))
}

/// Deletes the Source. Its files stay on disk.
#[tracing::instrument(skip_all, fields(source.id = %id))]
pub async fn delete(db: &Pool, id: SourceId) -> Result<(), DeleteError> {
    let deleted = sqlx::query!("DELETE FROM sources WHERE id = $1", id as SourceId)
        .with_operation("DELETE", "sources")
        .execute(db)
        .await
        .context("failed to delete the Source")?;

    if deleted.rows_affected() == 0 {
        return Err(DeleteError::SourceNotFound);
    }
    Ok(())
}

/// A row of the `sources` table, where each Source Type fills its own columns.
struct SourceRow {
    id: SourceId,
    source_type: SourceType,
    media_type: MediaType,
    path: Option<AbsoluteFolder>,
    url: Option<String>,
    api_key_encrypted: Option<EncryptedSecret>,
    quality_profile_id: Option<i32>,
    quality_profile_name: Option<String>,
    root_folder_path: Option<String>,
    local_root_folder_path: Option<AbsoluteFolder>,
}

impl SourceRow {
    /// Returns the Source the row stores, whose Source Type's columns the constraints filled.
    fn into_source(self) -> Source {
        const FILLED: &str = "the Source Type's constraint fills it";

        let configuration = match self.source_type.app() {
            None => SourceConfiguration::Filesystem(FilesystemConfiguration {
                media_type: self.media_type,
                path: self.path.expect(FILLED),
            }),
            Some(app) => SourceConfiguration::Servarr(ServarrConfiguration {
                app,
                url: self
                    .url
                    .expect(FILLED)
                    .parse()
                    .expect("the sources table has only URLs that `ApiUrl` parsed"),
                api_key: self.api_key_encrypted.expect(FILLED),
                quality_profile: QualityProfile {
                    id: self.quality_profile_id.expect(FILLED),
                    name: self.quality_profile_name.expect(FILLED),
                },
                root_folder_path: self.root_folder_path.expect(FILLED),
                local_root_folder_path: self.local_root_folder_path,
            }),
        };
        Source {
            id: self.id,
            configuration,
        }
    }
}
