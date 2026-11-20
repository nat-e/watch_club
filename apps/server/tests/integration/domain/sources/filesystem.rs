//! Filesystem Sources: the folder WatchClub looks for on the server before it saves one.

use sqlx::PgPool;
use watch_club::{
    domain::{
        contents::MediaType,
        sources::{
            self, ConfigurationError, ConfigurationInput, CreateError, FilesystemConfiguration,
            FilesystemConfigurationInput, Source, SourceConfiguration, SourceType,
        },
    },
    utils::filesystem::{AbsoluteFolder, FolderError},
};
use watch_club_test_macros::database_test;

use super::{FOLDER, OTHER_FOLDER, create, movies_folder};

#[database_test]
async fn creates_a_source_of_a_folder_with_its_path_tidied(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let configuration = ConfigurationInput::Filesystem(FilesystemConfigurationInput {
        media_type: MediaType::TvShowEpisode,
        path: format!(" {FOLDER}/ "),
    });

    let source = sources::create(&db, configuration).await.unwrap();

    assert_eq!(
        source.configuration,
        SourceConfiguration::Filesystem(FilesystemConfiguration {
            media_type: MediaType::TvShowEpisode,
            path: AbsoluteFolder::parse(FOLDER).await.unwrap(),
        })
    );
    assert_eq!(source.configuration.source_type(), SourceType::Filesystem);
    assert_eq!(source.configuration.media_type(), MediaType::TvShowEpisode);
    assert_eq!(sources::list(&db).await.unwrap(), [source]);
}

// `utils::filesystem` tests which paths lead to a folder
#[database_test]
async fn refuses_a_folder_the_server_cant_find(db: PgPool) {
    let db = watch_club::db::instrument(db);

    let result = sources::create(&db, movies_folder("/no/such/folder")).await;

    let Err(CreateError::InvalidConfiguration(error)) = result else {
        panic!("{result:?}");
    };
    assert_eq!(error, ConfigurationError::Filesystem(FolderError::NotFound));
    assert_eq!(sources::list(&db).await.unwrap(), Vec::<Source>::new());
}

#[database_test]
async fn changes_the_folder(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let source = create(&db, movies_folder(FOLDER)).await;

    let updated = sources::update(&db, source.id, movies_folder(&format!("{OTHER_FOLDER}/")))
        .await
        .unwrap();

    assert_eq!(
        updated,
        Source {
            id: source.id,
            configuration: SourceConfiguration::Filesystem(FilesystemConfiguration {
                media_type: MediaType::Movie,
                path: AbsoluteFolder::parse(OTHER_FOLDER).await.unwrap(),
            }),
        }
    );
    assert_eq!(sources::list(&db).await.unwrap(), [updated]);
}
