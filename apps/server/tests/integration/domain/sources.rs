//! Sources, through `domain::sources`: what every Source Type shares, such as listing and deleting.
//! `filesystem` and `servarr` test what each Source Type checks before WatchClub saves it, and
//! updating it.

mod filesystem;
mod servarr;

use sqlx::PgPool;
use watch_club::{
    db::Pool,
    domain::{
        contents::MediaType,
        sources::{
            self, ConfigurationInput, DeleteError, FilesystemConfigurationInput, Source, SourceId,
        },
    },
};
use watch_club_test_macros::database_test;

use crate::support::FakeServarr;

/// Folders that exist wherever the tests run
const FOLDER: &str = env!("CARGO_MANIFEST_DIR");
const OTHER_FOLDER: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/src");

/// Returns the configuration of a Filesystem Source of movies in this folder.
fn movies_folder(path: &str) -> ConfigurationInput {
    ConfigurationInput::Filesystem(FilesystemConfigurationInput {
        media_type: MediaType::Movie,
        path: path.to_owned(),
    })
}

/// Creates a Source with this configuration, which must be valid.
async fn create(db: &Pool, configuration: ConfigurationInput) -> Source {
    sources::create(db, configuration).await.unwrap()
}

/// Returns the ID that a deleted Source had.
async fn deleted_source_id(db: &Pool) -> SourceId {
    let source = create(db, movies_folder(FOLDER)).await;
    sources::delete(db, source.id).await.unwrap();
    source.id
}

#[database_test]
async fn lists_the_sources_oldest_first(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let first = create(&db, movies_folder(OTHER_FOLDER)).await;
    let second = create(
        &db,
        ConfigurationInput::Servarr(radarr.configuration_input()),
    )
    .await;
    let third = create(&db, movies_folder(FOLDER)).await;

    let listed = sources::list(&db).await.unwrap();

    assert_eq!(listed, [first, second, third]);
}

#[database_test]
async fn gets_a_source_by_its_id(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let source = create(&db, movies_folder(FOLDER)).await;
    let deleted = deleted_source_id(&db).await;

    assert_eq!(sources::get(&db, source.id).await.unwrap(), Some(source));
    assert_eq!(sources::get(&db, deleted).await.unwrap(), None);
}

#[database_test]
async fn deletes_the_source(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let kept = create(&db, movies_folder(FOLDER)).await;
    let deleted = create(&db, movies_folder(OTHER_FOLDER)).await;

    sources::delete(&db, deleted.id).await.unwrap();

    assert_eq!(sources::list(&db).await.unwrap(), [kept]);
}

#[database_test]
async fn fails_to_delete_a_source_that_doesnt_exist(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let id = deleted_source_id(&db).await;

    let result = sources::delete(&db, id).await;

    assert!(
        matches!(result, Err(DeleteError::SourceNotFound)),
        "{result:?}"
    );
}
