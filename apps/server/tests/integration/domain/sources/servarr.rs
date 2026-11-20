//! Radarr, Sonarr and Sportarr Sources: the Source Configuration WatchClub saves without calling
//! the app, and the API key it keeps. `connection` tests `test_servarr_connection`, which calls the
//! apps.

mod connection;

use secrecy::ExposeSecret;
use watch_club::{
    db::Pool,
    domain::sources::{
        self, ConfigurationError, ConfigurationInput, ConnectionError, QualityProfile, ServarrApp,
        ServarrConfigurationError, ServarrConfigurationInput, Source, SourceConfiguration,
    },
    utils::{encryption::EncryptionKey, filesystem::AbsoluteFolder},
};

use super::{FOLDER, create};
use crate::support::{
    self, FakeServarr,
    fake_servarr::{API_KEY, ROOT_FOLDER},
};

/// Creates a Source of this fake Radarr, with its API key.
async fn create_radarr_source(db: &Pool, radarr: &FakeServarr) -> Source {
    let configuration = radarr.configuration_input();
    create(db, ConfigurationInput::Servarr(configuration)).await
}

/// Returns the API key that the Source's configuration has, decrypted with this key.
fn decrypted_api_key(source: &Source, encryption_key: &EncryptionKey) -> String {
    let SourceConfiguration::Servarr(configuration) = &source.configuration else {
        panic!("not an app's Source: {source:?}");
    };
    let api_key = encryption_key.decrypt(&configuration.api_key).unwrap();
    api_key.expose_secret().to_owned()
}

/// Returns how many requests the fake app received.
async fn request_count(app: &FakeServarr) -> usize {
    app.server.received_requests().await.unwrap().len()
}

mod create {
    use sqlx::PgPool;
    use watch_club::{
        domain::{
            contents::MediaType,
            sources::{CreateError, SourceType},
        },
        utils::filesystem::FolderError,
    };
    use watch_club_test_macros::database_test;

    use super::*;

    /// Creates a Source of Radarr with this configuration, and returns its error.
    async fn configuration_error(
        db: &Pool,
        configuration: ServarrConfigurationInput,
    ) -> ServarrConfigurationError {
        let result = sources::create(db, ConfigurationInput::Servarr(configuration)).await;
        let Err(CreateError::InvalidConfiguration(ConfigurationError::Servarr(error))) = result
        else {
            panic!("{result:?}");
        };
        error
    }

    #[database_test]
    async fn creates_a_source_of_each_app_with_its_url_parsed_and_folder_tidied(db: PgPool) {
        let db = watch_club::db::instrument(db);

        for (fake, app, source_type, media_type) in [
            (
                FakeServarr::radarr().await,
                ServarrApp::Radarr,
                SourceType::Radarr,
                MediaType::Movie,
            ),
            (
                FakeServarr::sonarr().await,
                ServarrApp::Sonarr,
                SourceType::Sonarr,
                MediaType::TvShowEpisode,
            ),
            (
                FakeServarr::sportarr().await,
                ServarrApp::Sportarr,
                SourceType::Sportarr,
                MediaType::SportsEvent,
            ),
        ] {
            let configuration = ServarrConfigurationInput {
                url: format!(" {}/ ", fake.url()),
                local_root_folder_path: Some(format!(" {FOLDER}/ ")),
                ..fake.configuration_input()
            };

            let source = create(&db, ConfigurationInput::Servarr(configuration)).await;

            let SourceConfiguration::Servarr(saved) = &source.configuration else {
                panic!("{source:?}");
            };
            assert_eq!(saved.app, app);
            assert_eq!(saved.url.as_str(), format!("{}/", fake.url()));
            assert_eq!(
                saved.quality_profile,
                QualityProfile {
                    id: 4,
                    name: "HD-1080p".to_owned(),
                }
            );
            assert_eq!(saved.root_folder_path, ROOT_FOLDER);
            assert_eq!(
                saved
                    .local_root_folder_path
                    .as_ref()
                    .map(AbsoluteFolder::as_str),
                Some(FOLDER)
            );
            assert_eq!(
                decrypted_api_key(&source, &support::encryption_key()),
                API_KEY
            );
            assert_eq!(source.configuration.source_type(), source_type);
            assert_eq!(source.configuration.media_type(), media_type);
            // The connection test checked the app before
            assert_eq!(request_count(&fake).await, 0);
        }
        assert_eq!(sources::list(&db).await.unwrap().len(), 3);
    }

    #[database_test]
    async fn leaves_out_a_blank_local_root_folder(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let configuration = ServarrConfigurationInput {
            local_root_folder_path: Some("  ".to_owned()),
            ..radarr.configuration_input()
        };

        let source = create(&db, ConfigurationInput::Servarr(configuration)).await;

        let SourceConfiguration::Servarr(saved) = source.configuration else {
            panic!("{source:?}");
        };
        assert_eq!(saved.local_root_folder_path, None);
    }

    #[database_test]
    async fn refuses_an_app_without_an_api_key(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let configuration = ServarrConfigurationInput {
            api_key: None,
            ..radarr.configuration_input()
        };

        let error = configuration_error(&db, configuration).await;

        assert_eq!(
            error,
            ServarrConfigurationError::Connection(ConnectionError::InvalidApiKey)
        );
        assert_eq!(sources::list(&db).await.unwrap(), Vec::<Source>::new());
    }

    #[database_test]
    async fn refuses_a_url_that_cant_have_a_path(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        // Without `http://`, `radarr` is the URL's scheme
        let configuration = ServarrConfigurationInput {
            url: "radarr:7878".to_owned(),
            ..radarr.configuration_input()
        };

        let error = configuration_error(&db, configuration).await;

        assert_eq!(
            error,
            ServarrConfigurationError::Connection(ConnectionError::InvalidServarrUrl)
        );
    }

    #[database_test]
    async fn refuses_a_local_root_folder_that_isnt_on_the_server(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let configuration = ServarrConfigurationInput {
            local_root_folder_path: Some("/no/such/folder".to_owned()),
            ..radarr.configuration_input()
        };

        let error = configuration_error(&db, configuration).await;

        assert_eq!(
            error,
            ServarrConfigurationError::LocalRootFolder(FolderError::NotFound)
        );
    }
}

mod update {
    use sqlx::PgPool;
    use watch_club_test_macros::database_test;

    use super::*;

    #[database_test]
    async fn changes_the_apps_configuration(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_radarr_source(&db, &radarr).await;
        let any = QualityProfile {
            id: 1,
            name: "Any".to_owned(),
        };
        let configuration = ServarrConfigurationInput {
            quality_profile: any.clone(),
            local_root_folder_path: Some(FOLDER.to_owned()),
            ..radarr.configuration_input()
        };

        let updated = sources::update(&db, source.id, ConfigurationInput::Servarr(configuration))
            .await
            .unwrap();

        let SourceConfiguration::Servarr(saved) = &updated.configuration else {
            panic!("{updated:?}");
        };
        assert_eq!(updated.id, source.id);
        assert_eq!(saved.quality_profile, any);
        assert_eq!(
            saved
                .local_root_folder_path
                .as_ref()
                .map(AbsoluteFolder::as_str),
            Some(FOLDER)
        );
        assert_eq!(sources::list(&db).await.unwrap(), [updated]);
    }

    #[database_test]
    async fn keeps_the_saved_api_key_when_the_configuration_has_none(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_radarr_source(&db, &radarr).await;
        let configuration = ServarrConfigurationInput {
            api_key: None,
            ..radarr.configuration_input()
        };

        let updated = sources::update(&db, source.id, ConfigurationInput::Servarr(configuration))
            .await
            .unwrap();

        assert_eq!(updated, source);
    }

    #[database_test]
    async fn replaces_the_api_key_with_the_one_in_the_configuration(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_radarr_source(&db, &radarr).await;
        let configuration = ServarrConfigurationInput {
            api_key: Some(support::encryption_key().encrypt(&"new-api-key".into())),
            ..radarr.configuration_input()
        };

        let updated = sources::update(&db, source.id, ConfigurationInput::Servarr(configuration))
            .await
            .unwrap();

        assert_eq!(
            decrypted_api_key(&updated, &support::encryption_key()),
            "new-api-key"
        );
    }
}
