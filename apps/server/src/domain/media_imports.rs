//! Media Imports: the runs that bring a Source's Media Files into WatchClub. Each matches the files
//! its Source lists to the Parts of the Media they hold, saving those it can't match as Unmatched,
//! and removes the files its Source no longer lists. Its Source's history shows them.
//!
//! The Instance Administrator starts one with `start`, and the hourly schedule with
//! `start_scheduled`. Either queues a job that `run`s it. Only Radarr Sources import yet, whose
//! files `movies` matches.
//!
//! An import handles its files in batches, which it saves one at a time: when it stops, the next
//! import that handles new files goes on from there.

mod movies;
mod store;

use std::fmt::{self, Display, Formatter};

use anyhow::Context;
use jiff::Timestamp;
use serde::{Deserialize, Serialize};
use tracing::Level;
use utoipa::ToSchema;
use uuid::Uuid;

use super::{
    contents::{MediaId, metadata::MetadataProviders},
    sources::{
        self, SourceId, SourceType,
        servarr::{self, ListFilesError, MovieFile, TestConnectionError},
    },
};
use crate::{
    api_client::HttpClient,
    db::Pool,
    jobs::{self, ImportMedia},
    utils::encryption::EncryptionKey,
};

/// The Source Types whose Sources import Media Files
const IMPORTING_SOURCE_TYPES: [SourceType; 1] = [SourceType::Radarr];

/// The number of files an import matches and saves at once
const BATCH_SIZE: usize = 500;

/// The unique ID of a Media Import.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[sqlx(transparent)]
pub struct MediaImportId(Uuid);

impl Display for MediaImportId {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// What started a Media Import.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, sqlx::Type, ToSchema)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "media_import_trigger", rename_all = "snake_case")]
pub enum MediaImportTrigger {
    /// The Instance Administrator
    Manual,
    /// The hourly schedule
    Scheduled,
}

/// The files of its Source a Media Import handles.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "files_to_import", rename_all = "snake_case")]
pub enum FilesToImport {
    /// The files not imported yet
    New,
    /// Also the Unmatched files, which it tries to match again
    NewAndUnmatched,
    /// Every file, which it matches again
    All,
}

impl FilesToImport {
    /// Returns whether an import handles a file that's saved and matched, saved and Unmatched, or
    /// not saved yet, when `matched` is None.
    const fn includes(self, matched: Option<bool>) -> bool {
        match self {
            Self::New => matched.is_none(),
            Self::NewAndUnmatched => !matches!(matched, Some(true)),
            Self::All => true,
        }
    }
}

/// The state of a Media Import.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, sqlx::Type, ToSchema)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "media_import_state", rename_all = "snake_case")]
pub enum MediaImportState {
    /// Waiting for its job to run
    Waiting,
    Running,
    Completed,
    Failed,
}

/// The reason a Media Import failed.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, sqlx::Type, ToSchema)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "media_import_failure", rename_all = "snake_case")]
pub enum MediaImportFailure {
    /// Its Source's app didn't answer at its URL, or answered with an error
    InvalidServarrUrl,
    /// WatchClub can't decrypt the Source's API key, or its app rejects it
    InvalidApiKey,
    /// Something else went wrong, which the logs say
    InternalError,
    /// The server stopped while it ran
    Interrupted,
}

impl From<TestConnectionError> for MediaImportFailure {
    fn from(error: TestConnectionError) -> Self {
        match error {
            TestConnectionError::InvalidUrl => Self::InvalidServarrUrl,
            TestConnectionError::InvalidApiKey => Self::InvalidApiKey,
        }
    }
}

/// A Media Import, as its Source's history shows it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct MediaImport {
    pub id: MediaImportId,
    pub trigger: MediaImportTrigger,
    pub files_to_import: FilesToImport,
    pub state: MediaImportState,
    /// Why it failed, when it did
    #[schema(required = true)]
    pub failure: Option<MediaImportFailure>,
    /// The files it handles, once its Source listed them
    #[schema(required = true)]
    pub file_count: Option<i32>,
    /// The files it matched to their Content so far
    pub matched_file_count: i32,
    /// The files it saved as Unmatched so far
    pub unmatched_file_count: i32,
    /// The files it failed to handle so far, which stay as they were
    pub failed_file_count: i32,
    /// The Media Files it removed, as its Source no longer lists them
    pub removed_file_count: i32,
    /// When a person or the schedule started it
    #[schema(value_type = String, format = DateTime)]
    pub started_at: Timestamp,
    /// When it completed or failed
    #[schema(value_type = Option<String>, format = DateTime, required = true)]
    pub finished_at: Option<Timestamp>,
}

/// The reason a Media Import didn't start.
#[derive(Debug, thiserror::Error)]
pub enum StartMediaImportError {
    #[error("no such Source")]
    NotFound,
    /// Its Source Type doesn't import Media Files yet
    #[error("the Source's type doesn't import yet")]
    UnsupportedSourceType,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// The Parts of Media a file holds, which an import found: the Part numbered `number` of each Media.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct PartReference {
    media_id: MediaId,
    number: i32,
}

/// A file that an import handled, and what it found the file holds.
#[derive(Clone, Debug, PartialEq, Eq)]
struct ImportedFile<'a> {
    /// Where WatchClub sees it on the server
    path: &'a str,
    holds: Holds,
}

/// What an import found that a file holds.
#[derive(Clone, Debug, PartialEq, Eq)]
enum Holds {
    /// These Parts
    Parts(Vec<PartReference>),
    /// Nothing WatchClub knows, such as a Movie TMDB doesn't know: the file is Unmatched
    Nothing,
    /// An error kept the import from finding out, such as TMDB being down: the file stays as it was
    Unknown,
}

/// Starts an import of the Source's files that `files_to_import` says, for the Instance
/// Administrator, and returns it, waiting for its job.
#[tracing::instrument(skip_all, fields(source.id = %source_id))]
pub async fn start(
    db: &Pool,
    source_id: SourceId,
    files_to_import: FilesToImport,
) -> Result<MediaImport, StartMediaImportError> {
    let source = sources::get(db, source_id)
        .await?
        .ok_or(StartMediaImportError::NotFound)?;
    if !IMPORTING_SOURCE_TYPES.contains(&source.source_type()) {
        return Err(StartMediaImportError::UnsupportedSourceType);
    }

    // With its job, so that no import waits for a job that doesn't exist
    let mut transaction = db.begin().await.context("failed to start a transaction")?;
    let media_import = store::insert(
        &mut transaction,
        source_id,
        MediaImportTrigger::Manual,
        files_to_import,
    )
    .await?;
    jobs::enqueue(
        &mut transaction,
        ImportMedia {
            media_import_id: media_import.id,
        },
    )
    .await?;
    transaction
        .commit()
        .await
        .context("failed to start a Media Import")?;
    Ok(media_import)
}

/// Starts an import of the new and Unmatched files of every Source that imports, as the hourly
/// schedule does. Marks the imports that a stopped server left running as failed first.
#[tracing::instrument(skip_all)]
pub async fn start_scheduled(db: &Pool) -> anyhow::Result<()> {
    let interrupted = store::fail_interrupted(db).await?;
    if interrupted > 0 {
        tracing::event!(
            name: "media_imports.interrupted",
            Level::WARN,
            media_import.count = interrupted,
            "marked the Media Imports that a stopped server left running as failed",
        );
    }

    let mut transaction = db.begin().await.context("failed to start a transaction")?;
    let started = store::insert_scheduled(
        &mut transaction,
        &IMPORTING_SOURCE_TYPES,
        FilesToImport::NewAndUnmatched,
    )
    .await?;
    for media_import_id in started {
        jobs::enqueue(&mut transaction, ImportMedia { media_import_id }).await?;
    }
    transaction
        .commit()
        .await
        .context("failed to start the scheduled Media Imports")?;
    Ok(())
}

/// Returns the Source's imports, the latest first, or none when there's no such Source.
#[tracing::instrument(skip_all, fields(source.id = %source_id))]
pub async fn list(db: &Pool, source_id: SourceId) -> anyhow::Result<Vec<MediaImport>> {
    store::list(db, source_id).await
}

/// Deletes the imports that finished over 30 days ago, and returns how many.
#[tracing::instrument(skip_all)]
pub async fn delete_old(db: &Pool) -> anyhow::Result<u64> {
    store::delete_old(db).await
}

/// Runs the import, unless it already ran or its Source is gone, and saves how it ended. Fails when
/// something unexpected stopped it, which it saves too.
#[tracing::instrument(skip_all, fields(media_import.id = %id))]
pub async fn run(
    db: &Pool,
    metadata_providers: &MetadataProviders,
    http_client: &HttpClient,
    encryption_key: &EncryptionKey,
    id: MediaImportId,
) -> anyhow::Result<()> {
    let Some((source_id, files_to_import)) = store::claim(db, id).await? else {
        return Ok(());
    };

    let listed = match servarr::list_movie_files(db, encryption_key, http_client, source_id).await {
        Ok(listed) => listed,
        // Deleted meanwhile, with its imports
        Err(ListFilesError::NotFound) => return Ok(()),
        // Which `list_movie_files` logged
        Err(ListFilesError::Connection(error)) => {
            return store::finish(db, id, Some(error.into())).await;
        }
        Err(ListFilesError::Internal(error)) => return fail(db, id, error).await,
    };

    match import(
        db,
        metadata_providers,
        id,
        source_id,
        files_to_import,
        listed,
    )
    .await
    {
        Ok(()) => store::finish(db, id, None).await,
        Err(error) => fail(db, id, error).await,
    }
}

/// Removes the Source's files it no longer lists, then matches and saves those that
/// `files_to_import` says, in batches.
async fn import(
    db: &Pool,
    metadata_providers: &MetadataProviders,
    id: MediaImportId,
    source_id: SourceId,
    files_to_import: FilesToImport,
    listed: Vec<MovieFile>,
) -> anyhow::Result<()> {
    let saved = store::saved_files(db, source_id).await?;
    let listed_paths: Vec<_> = listed.iter().map(|file| file.path.as_str()).collect();
    let files: Vec<_> = listed
        .iter()
        .filter(|file| files_to_import.includes(saved.get(&file.path).copied()))
        .collect();
    store::remove_unlisted_files(db, id, source_id, &listed_paths, files.len()).await?;

    for batch in files.chunks(BATCH_SIZE) {
        let imported = movies::match_files(db, metadata_providers, batch).await?;
        store::save_files(db, id, source_id, &imported).await?;
    }
    Ok(())
}

/// Saves that the import failed, as something unexpected stopped it, and returns the error.
async fn fail(db: &Pool, id: MediaImportId, error: anyhow::Error) -> anyhow::Result<()> {
    // When this fails too, such as with the database down, the next hourly import marks it as
    // interrupted
    if let Err(save_error) = store::finish(db, id, Some(MediaImportFailure::InternalError)).await {
        tracing::event!(
            name: "media_imports.failure.unsaved",
            Level::ERROR,
            exception.message = %format_args!("{save_error:#}"),
            "failed to save that a Media Import failed",
        );
    }
    Err(error.context("a Media Import failed"))
}
