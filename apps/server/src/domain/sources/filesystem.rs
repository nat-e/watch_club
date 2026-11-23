//! Filesystem Sources: a folder on the server, whose files and subfolders' files all have one Media
//! Type.

use anyhow::Context;
use sqlx_otel::QueryAnnotateExt;

use super::{Source, SourceId, UpdateSourceError};
use crate::{db::Pool, domain::contents::MediaType, utils::filesystem::AbsoluteFolder};

/// Creates a Filesystem Source of the folder, whose files have the Media Type, and returns it.
#[tracing::instrument(skip_all)]
pub async fn create(
    db: &Pool,
    media_type: MediaType,
    path: AbsoluteFolder,
) -> anyhow::Result<Source> {
    let id = sqlx::query_scalar!(
        r#"
        INSERT INTO sources (source_type, media_type, path)
        VALUES ('filesystem', $1, $2)
        RETURNING id
        "#,
        media_type,
        &path as &AbsoluteFolder,
    )
    .with_operation("INSERT", "sources")
    .fetch_one(db)
    .await
    .context("failed to create the Filesystem Source")?;

    Ok(Source::Filesystem {
        id,
        media_type,
        path,
    })
}

/// Gives the Filesystem Source with this ID another folder, and returns it.
#[tracing::instrument(skip_all, fields(source.id = %id))]
pub async fn update(
    db: &Pool,
    id: SourceId,
    path: AbsoluteFolder,
) -> Result<Source, UpdateSourceError> {
    let media_type = sqlx::query_scalar!(
        r#"
        UPDATE sources
        SET path = $2
        WHERE id = $1 AND source_type = 'filesystem'
        RETURNING media_type
        "#,
        id as SourceId,
        &path as &AbsoluteFolder,
    )
    .with_operation("UPDATE", "sources")
    .fetch_optional(db)
    .await
    .context("failed to update the Filesystem Source")?
    .ok_or(UpdateSourceError::NotFound)?;

    Ok(Source::Filesystem {
        id,
        media_type,
        path,
    })
}
