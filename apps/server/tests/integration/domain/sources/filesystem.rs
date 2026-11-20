//! Filesystem Sources: creating and updating them.

use sqlx::PgPool;
use watch_club::{
    domain::{
        contents::MediaType,
        sources::{self, Source, SourceType, UpdateSourceError, filesystem},
    },
    utils::filesystem::AbsoluteFolder,
};
use watch_club_test_macros::database_test;

use super::{FOLDER, OTHER_FOLDER, create_app_source, create_movies_folder, deleted_source_id};
use crate::support::FakeServarr;

#[database_test]
async fn creates_a_source_of_a_folder(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let path = AbsoluteFolder::parse(FOLDER).await.unwrap();

    let source = filesystem::create(&db, MediaType::TvShowEpisode, path.clone())
        .await
        .unwrap();

    assert_eq!(
        source,
        Source::Filesystem {
            id: source.id(),
            media_type: MediaType::TvShowEpisode,
            path,
        }
    );
    assert_eq!(source.source_type(), SourceType::Filesystem);
    assert_eq!(sources::list(&db).await.unwrap(), [source]);
}

#[database_test]
async fn changes_the_folder(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let source = create_movies_folder(&db, FOLDER).await;
    let path = AbsoluteFolder::parse(OTHER_FOLDER).await.unwrap();

    let updated = filesystem::update(&db, source.id(), path.clone())
        .await
        .unwrap();

    let expected = Source::Filesystem {
        id: source.id(),
        media_type: MediaType::Movie,
        path,
    };
    assert_eq!(updated, expected);
    assert_eq!(sources::list(&db).await.unwrap(), [expected]);
}

#[database_test]
async fn updates_only_a_filesystem_source(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let app = create_app_source(&db, &radarr).await;
    let deleted = deleted_source_id(&db).await;
    let path = AbsoluteFolder::parse(OTHER_FOLDER).await.unwrap();

    for id in [app.id(), deleted] {
        let result = filesystem::update(&db, id, path.clone()).await;

        assert!(
            matches!(result, Err(UpdateSourceError::NotFound)),
            "{result:?}"
        );
    }
    assert_eq!(sources::list(&db).await.unwrap(), [app]);
}
