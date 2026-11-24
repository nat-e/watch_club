//! The saved Media Imports, and the Media Files they save: each file with the Parts it holds, in
//! `media_file_parts`, or none when it's Unmatched. Saving a batch of files writes each table with
//! one statement, whatever the number of files.

use std::collections::HashMap;

use anyhow::Context;
use jiff_sqlx::Timestamp;
use sqlx_otel::QueryAnnotateExt;

use super::{
    FilesToImport, Holds, ImportedFile, MediaImport, MediaImportFailure, MediaImportId,
    MediaImportState, MediaImportTrigger,
};
use crate::{
    db::{Pool, Transaction},
    domain::{
        contents::MediaId,
        sources::{SourceId, SourceType},
    },
};

/// A row of the `media_imports` table.
struct MediaImportRow {
    id: MediaImportId,
    trigger: MediaImportTrigger,
    files_to_import: FilesToImport,
    state: MediaImportState,
    failure: Option<MediaImportFailure>,
    file_count: Option<i32>,
    matched_file_count: i32,
    unmatched_file_count: i32,
    failed_file_count: i32,
    removed_file_count: i32,
    started_at: Timestamp,
    finished_at: Option<Timestamp>,
}

impl From<MediaImportRow> for MediaImport {
    fn from(row: MediaImportRow) -> Self {
        Self {
            id: row.id,
            trigger: row.trigger,
            files_to_import: row.files_to_import,
            state: row.state,
            failure: row.failure,
            file_count: row.file_count,
            matched_file_count: row.matched_file_count,
            unmatched_file_count: row.unmatched_file_count,
            failed_file_count: row.failed_file_count,
            removed_file_count: row.removed_file_count,
            started_at: row.started_at.to_jiff(),
            finished_at: row.finished_at.map(Timestamp::to_jiff),
        }
    }
}

/// Inserts an import of the Source, waiting for its job, and returns it.
pub(super) async fn insert(
    transaction: &mut Transaction,
    source_id: SourceId,
    trigger: MediaImportTrigger,
    files_to_import: FilesToImport,
) -> anyhow::Result<MediaImport> {
    let row = sqlx::query_as!(
        MediaImportRow,
        r#"
        INSERT INTO media_imports (source_id, trigger, files_to_import)
        VALUES ($1, $2, $3)
        RETURNING id, trigger, files_to_import, state, failure, file_count, matched_file_count,
            unmatched_file_count, failed_file_count, removed_file_count, started_at, finished_at
        "#,
        source_id as SourceId,
        trigger as MediaImportTrigger,
        files_to_import as FilesToImport,
    )
    .with_operation("INSERT", "media_imports")
    .fetch_one(&mut *transaction)
    .await
    .context("failed to insert a Media Import")?;
    Ok(row.into())
}

/// Inserts a scheduled import for each Source of these types, waiting for its job, and returns
/// their IDs.
pub(super) async fn insert_scheduled(
    transaction: &mut Transaction,
    source_types: &[SourceType],
    files_to_import: FilesToImport,
) -> anyhow::Result<Vec<MediaImportId>> {
    let ids = sqlx::query_scalar!(
        r#"
        INSERT INTO media_imports (source_id, trigger, files_to_import)
        SELECT id, 'scheduled', $2
        FROM sources
        WHERE source_type = ANY($1)
        RETURNING id
        "#,
        source_types as _,
        files_to_import as FilesToImport,
    )
    .with_operation("INSERT", "media_imports")
    .fetch_all(&mut *transaction)
    .await
    .context("failed to insert the scheduled Media Imports")?;
    Ok(ids)
}

/// Returns the Source's imports, the latest first.
pub(super) async fn list(db: &Pool, source_id: SourceId) -> anyhow::Result<Vec<MediaImport>> {
    let rows = sqlx::query_as!(
        MediaImportRow,
        r#"
        SELECT id, trigger, files_to_import, state, failure, file_count, matched_file_count,
            unmatched_file_count, failed_file_count, removed_file_count, started_at, finished_at
        FROM media_imports
        WHERE source_id = $1
        ORDER BY started_at DESC, id DESC
        "#,
        source_id as SourceId,
    )
    .with_operation("SELECT", "media_imports")
    .fetch_all(db)
    .await
    .context("failed to list a Source's Media Imports")?;
    Ok(rows.into_iter().map(MediaImport::from).collect())
}

/// Marks the import as running, and returns its Source and the files it handles, or None when it
/// isn't waiting anymore, such as when it already ran or its Source is gone.
pub(super) async fn claim(
    db: &Pool,
    id: MediaImportId,
) -> anyhow::Result<Option<(SourceId, FilesToImport)>> {
    let claimed = sqlx::query!(
        r#"
        UPDATE media_imports
        SET state = 'running', job_started_at = now()
        WHERE id = $1 AND state = 'waiting'
        RETURNING source_id, files_to_import
        "#,
        id as MediaImportId,
    )
    .with_operation("UPDATE", "media_imports")
    .fetch_optional(db)
    .await
    .context("failed to start a Media Import")?;
    Ok(claimed.map(|row| (row.source_id, row.files_to_import)))
}

/// Marks the running import as completed, or failed with the reason.
pub(super) async fn finish(
    db: &Pool,
    id: MediaImportId,
    failure: Option<MediaImportFailure>,
) -> anyhow::Result<()> {
    let state = match failure {
        None => MediaImportState::Completed,
        Some(_) => MediaImportState::Failed,
    };
    sqlx::query!(
        r#"
        UPDATE media_imports
        SET state = $2, failure = $3, finished_at = now()
        WHERE id = $1 AND state = 'running'
        "#,
        id as MediaImportId,
        state as MediaImportState,
        failure as Option<MediaImportFailure>,
    )
    .with_operation("UPDATE", "media_imports")
    .execute(db)
    .await
    .context("failed to finish a Media Import")?;
    Ok(())
}

/// Marks the imports that a stopped server left running as failed, and returns how many.
pub(super) async fn fail_interrupted(db: &Pool) -> anyhow::Result<u64> {
    // The job runner stops a job after 59 minutes, so one that started over an hour ago stopped
    // without saving how it ended
    let interrupted = sqlx::query!(
        r#"
        UPDATE media_imports
        SET state = 'failed', failure = 'interrupted', finished_at = now()
        WHERE state = 'running' AND job_started_at < now() - interval '1 hour'
        "#
    )
    .with_operation("UPDATE", "media_imports")
    .execute(db)
    .await
    .context("failed to mark the interrupted Media Imports")?;
    Ok(interrupted.rows_affected())
}

/// Deletes the imports that finished over 30 days ago, and returns how many.
pub(super) async fn delete_old(db: &Pool) -> anyhow::Result<u64> {
    let deleted =
        sqlx::query!("DELETE FROM media_imports WHERE finished_at < now() - interval '30 days'")
            .with_operation("DELETE", "media_imports")
            .execute(db)
            .await
            .context("failed to delete the old Media Imports")?;
    Ok(deleted.rows_affected())
}

/// Returns the paths of the Source's files, with whether each holds Parts: false when it's
/// Unmatched.
pub(super) async fn saved_files(
    db: &Pool,
    source_id: SourceId,
) -> anyhow::Result<HashMap<String, bool>> {
    let files = sqlx::query!(
        r#"
        SELECT f.path,
            EXISTS (SELECT FROM media_file_parts fp WHERE fp.media_file_id = f.id) AS "matched!"
        FROM media_files f
        WHERE f.source_id = $1
        "#,
        source_id as SourceId,
    )
    .with_operation("SELECT", "media_files")
    .fetch_all(db)
    .await
    .context("failed to list a Source's Media Files")?;
    Ok(files
        .into_iter()
        .map(|file| (file.path, file.matched))
        .collect())
}

/// Deletes the Source's files whose paths it no longer lists, and saves how many in the import, with
/// the number of files it handles.
pub(super) async fn remove_unlisted_files(
    db: &Pool,
    id: MediaImportId,
    source_id: SourceId,
    listed_paths: &[&str],
    file_count: usize,
) -> anyhow::Result<()> {
    let file_count = i32::try_from(file_count).context("too many files to import")?;

    // Compares the paths with NOT EXISTS, which Postgres hashes, rather than with `<> ALL`, which
    // would compare every file with every listed path
    sqlx::query!(
        r#"
        WITH removed AS (
            DELETE FROM media_files
            WHERE source_id = $2
                AND NOT EXISTS (
                    SELECT FROM UNNEST($3::text[]) AS listed (path)
                    WHERE listed.path = media_files.path
                )
            RETURNING 1
        )
        UPDATE media_imports
        SET file_count = $4, removed_file_count = (SELECT count(*) FROM removed)
        WHERE id = $1
        "#,
        id as MediaImportId,
        source_id as SourceId,
        listed_paths as &[&str],
        file_count,
    )
    .with_operation("DELETE", "media_files")
    .execute(db)
    .await
    .context("failed to remove the Media Files a Source no longer lists")?;
    Ok(())
}

/// Saves the files of the Source that the import handled, in one transaction: inserts those not
/// saved yet, replaces the Parts each holds, adding the Parts that don't exist yet, and adds them to
/// the import's counts. Leaves the files it found nothing about as they were.
pub(super) async fn save_files(
    db: &Pool,
    id: MediaImportId,
    source_id: SourceId,
    files: &[ImportedFile<'_>],
) -> anyhow::Result<()> {
    let mut paths = Vec::new();
    let mut link_paths = Vec::new();
    let mut link_media_ids = Vec::new();
    let mut link_numbers = Vec::new();
    let (mut matched, mut unmatched, mut failed) = (0, 0, 0);
    for file in files {
        match &file.holds {
            Holds::Parts(parts) => {
                matched += 1;
                paths.push(file.path);
                for part in parts {
                    link_paths.push(file.path);
                    link_media_ids.push(part.media_id);
                    link_numbers.push(part.number);
                }
            }
            Holds::Nothing => {
                unmatched += 1;
                paths.push(file.path);
            }
            Holds::Unknown => failed += 1,
        }
    }

    let mut transaction = db.begin().await.context("failed to start a transaction")?;

    sqlx::query!(
        r#"
        INSERT INTO media_parts (media_id, number)
        SELECT DISTINCT * FROM UNNEST($1::uuid[], $2::integer[])
        ON CONFLICT (media_id, number) DO NOTHING
        "#,
        &link_media_ids as &[MediaId],
        &link_numbers as &[i32],
    )
    .with_operation("INSERT", "media_parts")
    .execute(&mut transaction)
    .await
    .context("failed to save the Parts of Media Files")?;

    sqlx::query!(
        r#"
        INSERT INTO media_files (source_id, path)
        SELECT $1, path FROM UNNEST($2::text[]) AS path
        ON CONFLICT (source_id, path) DO NOTHING
        "#,
        source_id as SourceId,
        &paths as &[&str],
    )
    .with_operation("INSERT", "media_files")
    .execute(&mut transaction)
    .await
    .context("failed to save Media Files")?;

    sqlx::query!(
        r#"
        DELETE FROM media_file_parts
        WHERE media_file_id IN (
            SELECT id FROM media_files WHERE source_id = $1 AND path = ANY($2)
        )
        "#,
        source_id as SourceId,
        &paths as &[&str],
    )
    .with_operation("DELETE", "media_file_parts")
    .execute(&mut transaction)
    .await
    .context("failed to delete the former Parts of Media Files")?;

    sqlx::query!(
        r#"
        INSERT INTO media_file_parts (media_file_id, media_part_id)
        SELECT f.id, p.id
        FROM UNNEST($2::text[], $3::uuid[], $4::integer[]) AS link (path, media_id, number)
        JOIN media_files f ON f.source_id = $1 AND f.path = link.path
        JOIN media_parts p ON p.media_id = link.media_id AND p.number = link.number
        ON CONFLICT DO NOTHING
        "#,
        source_id as SourceId,
        &link_paths as &[&str],
        &link_media_ids as &[MediaId],
        &link_numbers as &[i32],
    )
    .with_operation("INSERT", "media_file_parts")
    .execute(&mut transaction)
    .await
    .context("failed to save the Parts that Media Files hold")?;

    sqlx::query!(
        r#"
        UPDATE media_imports
        SET matched_file_count = matched_file_count + $2,
            unmatched_file_count = unmatched_file_count + $3,
            failed_file_count = failed_file_count + $4
        WHERE id = $1
        "#,
        id as MediaImportId,
        matched,
        unmatched,
        failed,
    )
    .with_operation("UPDATE", "media_imports")
    .execute(&mut transaction)
    .await
    .context("failed to count the files a Media Import saved")?;

    transaction
        .commit()
        .await
        .context("failed to save Media Files")?;
    Ok(())
}
