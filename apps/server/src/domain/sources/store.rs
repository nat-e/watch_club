//! Saves the Sources in the `sources` table, where each Source Type fills its own columns, which
//! the table's constraints check. It saves the Source Configurations it's given:
//! `domain::sources` validates them first.

use anyhow::Context;
use sqlx_otel::QueryAnnotateExt;

use super::{
    FilesystemConfiguration, QualityProfile, ServarrConfiguration, Source, SourceConfiguration,
    SourceId, SourceType,
};
use crate::{
    db::Pool,
    domain::contents::MediaType,
    utils::{encryption::EncryptedSecret, filesystem::AbsoluteFolder},
};

/// Returns every Source, oldest first.
pub(super) async fn list(db: &Pool) -> anyhow::Result<Vec<Source>> {
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
pub(super) async fn get_by_id(db: &Pool, id: SourceId) -> anyhow::Result<Option<Source>> {
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

/// Saves a Source with this configuration, and returns it with its new ID.
pub(super) async fn insert(
    db: &Pool,
    configuration: SourceConfiguration,
) -> anyhow::Result<Source> {
    let id = match &configuration {
        SourceConfiguration::Filesystem(filesystem) => {
            sqlx::query_scalar!(
                r#"
                INSERT INTO sources (source_type, media_type, path)
                VALUES ('filesystem', $1, $2)
                RETURNING id
                "#,
                filesystem.media_type,
                &filesystem.path as &AbsoluteFolder,
            )
            .with_operation("INSERT", "sources")
            .fetch_one(db)
            .await
        }
        SourceConfiguration::Servarr(servarr) => {
            sqlx::query_scalar!(
                r#"
                INSERT INTO sources (
                    source_type, media_type, url, api_key_encrypted, quality_profile_id,
                    quality_profile_name, root_folder_path, local_root_folder_path
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                RETURNING id
                "#,
                configuration.source_type(),
                configuration.media_type(),
                servarr.url.as_str(),
                &servarr.api_key as &EncryptedSecret,
                servarr.quality_profile.id,
                servarr.quality_profile.name,
                servarr.root_folder_path,
                servarr.local_root_folder_path.as_ref() as Option<&AbsoluteFolder>,
            )
            .with_operation("INSERT", "sources")
            .fetch_one(db)
            .await
        }
    }
    .context("failed to create the Source")?;

    Ok(Source { id, configuration })
}

/// Deletes the Source with this ID, and returns whether there was one.
pub(super) async fn delete(db: &Pool, id: SourceId) -> anyhow::Result<bool> {
    let deleted = sqlx::query!("DELETE FROM sources WHERE id = $1", id as SourceId)
        .with_operation("DELETE", "sources")
        .execute(db)
        .await
        .context("failed to delete the Source")?;

    Ok(deleted.rows_affected() > 0)
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
                    .expect("the sources table has only the URLs that `validate` parsed"),
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
