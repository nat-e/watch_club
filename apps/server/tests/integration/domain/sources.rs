//! Sources, through `domain::sources`: what every Source Type shares, such as listing, deleting and
//! keeping its type. `filesystem` and `servarr` test what each Source Type checks before WatchClub
//! saves it.

mod filesystem;
mod servarr;

use sqlx::PgPool;
use watch_club::{
    db::Pool,
    domain::{
        contents::MediaType,
        sources::{
            self, CheckExistingServarrSourceError, ConfigurationError, ConfigurationInput,
            DeleteError, FilesystemConfigurationInput, Source, SourceId, UpdateError,
        },
    },
    utils::filesystem::FolderError,
};
use watch_club_test_macros::database_test;

use crate::support::{self, FakeServarr};

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
    sources::create(
        db,
        configuration,
        &support::encryption_key(),
        &support::http_client(),
    )
    .await
    .unwrap()
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

#[database_test]
async fn fails_to_update_a_source_that_doesnt_exist(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let id = deleted_source_id(&db).await;

    let result = sources::update(
        &db,
        id,
        movies_folder(FOLDER),
        &support::encryption_key(),
        &support::http_client(),
    )
    .await;

    assert!(
        matches!(result, Err(UpdateError::SourceNotFound)),
        "{result:?}"
    );
}

#[database_test]
async fn keeps_the_sources_type_and_media_type(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let sonarr = FakeServarr::sonarr().await;
    let folder = create(&db, movies_folder(FOLDER)).await;
    let app = create(
        &db,
        ConfigurationInput::Servarr(radarr.configuration_input()),
    )
    .await;
    let tv_shows_folder = ConfigurationInput::Filesystem(FilesystemConfigurationInput {
        media_type: MediaType::TvShowEpisode,
        path: FOLDER.to_owned(),
    });

    for (source, configuration) in [
        (&folder, tv_shows_folder),
        (
            &folder,
            ConfigurationInput::Servarr(radarr.configuration_input()),
        ),
        (
            &app,
            ConfigurationInput::Servarr(sonarr.configuration_input()),
        ),
        (&app, movies_folder(FOLDER)),
    ] {
        let result = sources::update(
            &db,
            source.id,
            configuration,
            &support::encryption_key(),
            &support::http_client(),
        )
        .await;

        assert!(
            matches!(result, Err(UpdateError::TypeChanged)),
            "{result:?}"
        );
    }
    assert_eq!(sources::list(&db).await.unwrap(), [folder, app]);
}

#[database_test]
async fn keeps_the_saved_configuration_when_the_new_one_is_invalid(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let source = create(&db, movies_folder(FOLDER)).await;

    let result = sources::update(
        &db,
        source.id,
        movies_folder("/no/such/folder"),
        &support::encryption_key(),
        &support::http_client(),
    )
    .await;

    let Err(UpdateError::InvalidConfiguration(error)) = result else {
        panic!("{result:?}");
    };
    assert_eq!(error, ConfigurationError::Filesystem(FolderError::NotFound));
    assert_eq!(sources::list(&db).await.unwrap(), [source]);
}

#[database_test]
async fn checks_only_the_apps_of_sources_that_exist(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let folder = create(&db, movies_folder(FOLDER)).await;
    let deleted = deleted_source_id(&db).await;

    for id in [folder.id, deleted] {
        let result = sources::check_existing_servarr_source(
            &db,
            id,
            "http://radarr:7878",
            None,
            &support::encryption_key(),
            &support::http_client(),
        )
        .await;

        assert!(
            matches!(result, Err(CheckExistingServarrSourceError::SourceNotFound)),
            "{result:?}"
        );
    }
}
