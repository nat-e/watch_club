//! Sources: where WatchClub imports Media Files from. A Filesystem Source is a folder on the
//! server; the others are a Radarr, Sonarr or Sportarr app, which downloads the Content its Source
//! requests. Only the Instance Administrator manages them.
//!
//! This module lists, finds and deletes the Sources of every Source Type. Each type's module,
//! `filesystem` or `servarr`, creates and updates its own, and `servarr` also tests the connection
//! to Radarr, Sonarr and Sportarr apps. The `sources` table has a column for each Source
//! Configuration's setting: each Source Type fills its own, which the table's constraints check.

pub mod filesystem;
pub mod servarr;

use std::fmt::{self, Display, Formatter};

use anyhow::Context;
use serde::{Deserialize, Serialize};
use sqlx_otel::QueryAnnotateExt;
use utoipa::ToSchema;
use uuid::Uuid;

use self::servarr::{QualityProfile, ServarrApp, ServarrConfiguration};
use crate::{db::Pool, domain::contents::MediaType, utils::filesystem::AbsoluteFolder};

/// The unique ID of a Source.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[sqlx(transparent)]
pub struct SourceId(Uuid);

impl Display for SourceId {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// The kind of place WatchClub imports Media Files from.
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

/// A Source, with its Source Configuration. Its Source Type and Media Type never change.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Source {
    /// A folder on the server, whose files and subfolders' files all have the Media Type
    Filesystem {
        id: SourceId,
        media_type: MediaType,
        path: AbsoluteFolder,
    },
    /// A Radarr, Sonarr or Sportarr app
    Servarr {
        id: SourceId,
        app: ServarrApp,
        configuration: ServarrConfiguration,
    },
}

impl Source {
    pub const fn id(&self) -> SourceId {
        match self {
            Self::Filesystem { id, .. } | Self::Servarr { id, .. } => *id,
        }
    }

    pub fn source_type(&self) -> SourceType {
        match self {
            Self::Filesystem { .. } => SourceType::Filesystem,
            Self::Servarr { app, .. } => (*app).into(),
        }
    }

    /// Returns the Media Type of the files the Source brings: the one a Filesystem Source was
    /// created with, or its app's.
    pub const fn media_type(&self) -> MediaType {
        match self {
            Self::Filesystem { media_type, .. } => *media_type,
            Self::Servarr { app, .. } => app.media_type(),
        }
    }
}

/// The reason a Source wasn't updated.
#[derive(Debug, thiserror::Error)]
pub enum UpdateSourceError {
    /// There's no Source of the type with the ID, such as one deleted meanwhile
    #[error("no such Source")]
    NotFound,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// The reason a Source wasn't deleted.
#[derive(Debug, thiserror::Error)]
pub enum DeleteSourceError {
    #[error("no such Source")]
    NotFound,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Returns every Source, oldest first.
#[tracing::instrument(skip_all)]
pub async fn list(db: &Pool) -> anyhow::Result<Vec<Source>> {
    let rows = sqlx::query_as!(
        SourceRow,
        r#"
        SELECT id, source_type, media_type, path, url, quality_profile_id, quality_profile_name,
            root_folder_path, local_root_folder_path
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
pub async fn get(db: &Pool, id: SourceId) -> anyhow::Result<Option<Source>> {
    let row = sqlx::query_as!(
        SourceRow,
        r#"
        SELECT id, source_type, media_type, path, url, quality_profile_id, quality_profile_name,
            root_folder_path, local_root_folder_path
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
pub async fn delete(db: &Pool, id: SourceId) -> Result<(), DeleteSourceError> {
    let deleted = sqlx::query!("DELETE FROM sources WHERE id = $1", id as SourceId)
        .with_operation("DELETE", "sources")
        .execute(db)
        .await
        .context("failed to delete the Source")?;

    if deleted.rows_affected() == 0 {
        return Err(DeleteSourceError::NotFound);
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
    quality_profile_id: Option<i32>,
    quality_profile_name: Option<String>,
    root_folder_path: Option<String>,
    local_root_folder_path: Option<AbsoluteFolder>,
}

impl SourceRow {
    /// Returns the Source the row stores, whose Source Type's columns the constraints filled.
    fn into_source(self) -> Source {
        const FILLED: &str = "the Source Type's constraint fills it";

        match self.source_type.app() {
            None => Source::Filesystem {
                id: self.id,
                media_type: self.media_type,
                path: self.path.expect(FILLED),
            },
            Some(app) => Source::Servarr {
                id: self.id,
                app,
                configuration: ServarrConfiguration {
                    url: self
                        .url
                        .expect(FILLED)
                        .parse()
                        .expect("the sources table has only URLs that `ApiUrl` parsed"),
                    quality_profile: QualityProfile {
                        id: self.quality_profile_id.expect(FILLED),
                        name: self.quality_profile_name.expect(FILLED),
                    },
                    root_folder_path: self.root_folder_path.expect(FILLED),
                    local_root_folder_path: self.local_root_folder_path,
                },
            },
        }
    }
}
