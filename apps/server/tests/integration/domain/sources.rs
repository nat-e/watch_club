//! Sources, through `domain::sources`: listing, finding and deleting them, whatever their Source
//! Type. `filesystem` and `servarr` test creating and updating each type's.

mod filesystem;
mod servarr;

use sqlx::PgPool;
use watch_club::{
    db::Pool,
    domain::{
        contents::MediaType,
        sources::{self, DeleteError, Source, SourceId},
    },
    utils::filesystem::AbsoluteFolder,
};
use watch_club_test_macros::database_test;

use crate::support::FakeServarr;

/// Folders that exist wherever the tests run
const FOLDER: &str = env!("CARGO_MANIFEST_DIR");
const OTHER_FOLDER: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/src");

/// Creates a Filesystem Source of movies in this folder, which must exist.
async fn create_movies_folder(db: &Pool, path: &str) -> Source {
    let path = AbsoluteFolder::parse(path).await.unwrap();
    sources::create_filesystem_source(db, MediaType::Movie, path)
        .await
        .unwrap()
}

/// Creates a Source of this fake app, with its API key.
async fn create_app_source(db: &Pool, app: &FakeServarr) -> Source {
    sources::create_servarr_source(db, app.source_configuration())
        .await
        .unwrap()
}

/// Returns the ID that a deleted Source had.
async fn deleted_source_id(db: &Pool) -> SourceId {
    let source = create_movies_folder(db, FOLDER).await;
    sources::delete(db, source.id).await.unwrap();
    source.id
}

#[database_test]
async fn lists_the_sources_oldest_first(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let first = create_movies_folder(&db, OTHER_FOLDER).await;
    let second = create_app_source(&db, &radarr).await;
    let third = create_movies_folder(&db, FOLDER).await;

    let listed = sources::list(&db).await.unwrap();

    assert_eq!(listed, [first, second, third]);
}

#[database_test]
async fn gets_a_source_by_its_id(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let source = create_movies_folder(&db, FOLDER).await;
    let deleted = deleted_source_id(&db).await;

    assert_eq!(sources::get(&db, source.id).await.unwrap(), Some(source));
    assert_eq!(sources::get(&db, deleted).await.unwrap(), None);
}

#[database_test]
async fn deletes_the_source(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let kept = create_movies_folder(&db, FOLDER).await;
    let deleted = create_movies_folder(&db, OTHER_FOLDER).await;

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
