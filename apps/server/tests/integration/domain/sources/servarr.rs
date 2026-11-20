//! Radarr, Sonarr and Sportarr Sources: the app WatchClub calls before it saves one, and the API key
//! it keeps. `gateway` tests `Servarr`, which calls the apps.

mod gateway;

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
        let configuration = ConfigurationInput::Servarr(configuration);
        let result = sources::create(
            db,
            configuration,
            &support::encryption_key(),
            &support::http_client(),
        )
        .await;
        let Err(CreateError::InvalidConfiguration(ConfigurationError::Servarr(error))) = result
        else {
            panic!("{result:?}");
        };
        error
    }

    #[database_test]
    async fn creates_a_source_of_each_app_with_its_url_and_folder_tidied(db: PgPool) {
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
            assert_eq!(saved.url, fake.url());
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
    async fn refuses_an_app_without_an_api_key_without_calling_it(db: PgPool) {
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
        assert_eq!(request_count(&radarr).await, 0);
        assert_eq!(sources::list(&db).await.unwrap(), Vec::<Source>::new());
    }

    #[database_test]
    async fn refuses_an_api_key_the_app_rejects(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let configuration = ServarrConfigurationInput {
            api_key: Some(support::encryption_key().encrypt(&"wrong-key".into())),
            ..radarr.configuration_input()
        };

        let error = configuration_error(&db, configuration).await;

        assert_eq!(
            error,
            ServarrConfigurationError::Connection(ConnectionError::InvalidApiKey)
        );
    }

    #[database_test]
    async fn refuses_a_url_where_another_app_answers(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let sonarr = FakeServarr::sonarr().await;

        let error = configuration_error(
            &db,
            ServarrConfigurationInput {
                app: ServarrApp::Radarr,
                ..sonarr.configuration_input()
            },
        )
        .await;

        assert_eq!(
            error,
            ServarrConfigurationError::Connection(ConnectionError::InvalidServarrUrl)
        );
    }

    #[database_test]
    async fn refuses_a_quality_profile_the_app_doesnt_have(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let configuration = ServarrConfigurationInput {
            quality_profile_id: 2,
            ..radarr.configuration_input()
        };

        let error = configuration_error(&db, configuration).await;

        assert_eq!(error, ServarrConfigurationError::QualityProfile);
    }

    #[database_test]
    async fn refuses_a_root_folder_the_app_doesnt_have(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let configuration = ServarrConfigurationInput {
            root_folder_path: "/tv".to_owned(),
            ..radarr.configuration_input()
        };

        let error = configuration_error(&db, configuration).await;

        assert_eq!(error, ServarrConfigurationError::RootFolder);
    }

    #[database_test]
    async fn checks_the_local_root_folder_before_calling_the_app(db: PgPool) {
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
        assert_eq!(request_count(&radarr).await, 0);
    }
}

mod update {
    use sqlx::PgPool;
    use watch_club::domain::sources::UpdateError;
    use watch_club_test_macros::database_test;

    use super::*;

    #[database_test]
    async fn changes_the_apps_configuration(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_radarr_source(&db, &radarr).await;
        let configuration = ServarrConfigurationInput {
            quality_profile_id: 1,
            local_root_folder_path: Some(FOLDER.to_owned()),
            ..radarr.configuration_input()
        };

        let updated = sources::update(
            &db,
            source.id,
            ConfigurationInput::Servarr(configuration),
            &support::encryption_key(),
            &support::http_client(),
        )
        .await
        .unwrap();

        let SourceConfiguration::Servarr(saved) = &updated.configuration else {
            panic!("{updated:?}");
        };
        assert_eq!(updated.id, source.id);
        assert_eq!(
            saved.quality_profile,
            QualityProfile {
                id: 1,
                name: "Any".to_owned(),
            }
        );
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

        let updated = sources::update(
            &db,
            source.id,
            ConfigurationInput::Servarr(configuration),
            &support::encryption_key(),
            &support::http_client(),
        )
        .await
        .unwrap();

        // The fake app takes only its API key, which the configuration didn't have
        assert_eq!(updated, source);
    }

    #[database_test]
    async fn replaces_the_api_key_with_the_one_in_the_configuration(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let moved_radarr = FakeServarr::radarr_with_api_key("new-api-key").await;
        let source = create_radarr_source(&db, &radarr).await;
        let with_saved_key = ServarrConfigurationInput {
            api_key: None,
            ..moved_radarr.configuration_input()
        };
        let with_new_key = moved_radarr.configuration_input();

        let refused = sources::update(
            &db,
            source.id,
            ConfigurationInput::Servarr(with_saved_key),
            &support::encryption_key(),
            &support::http_client(),
        )
        .await;
        let updated = sources::update(
            &db,
            source.id,
            ConfigurationInput::Servarr(with_new_key),
            &support::encryption_key(),
            &support::http_client(),
        )
        .await
        .unwrap();

        let Err(UpdateError::InvalidConfiguration(error)) = refused else {
            panic!("{refused:?}");
        };
        assert_eq!(
            error,
            ConfigurationError::Servarr(ServarrConfigurationError::Connection(
                ConnectionError::InvalidApiKey
            ))
        );
        assert_eq!(
            decrypted_api_key(&updated, &support::encryption_key()),
            "new-api-key"
        );
    }

    #[database_test]
    async fn asks_for_the_api_key_again_when_another_key_encrypted_it(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_radarr_source(&db, &radarr).await;
        let another_key = support::another_encryption_key();
        let with_saved_key = ServarrConfigurationInput {
            api_key: None,
            ..radarr.configuration_input()
        };
        let with_api_key_again = ServarrConfigurationInput {
            api_key: Some(another_key.encrypt(&API_KEY.into())),
            ..radarr.configuration_input()
        };
        let requests_before = request_count(&radarr).await;

        let refused = sources::update(
            &db,
            source.id,
            ConfigurationInput::Servarr(with_saved_key),
            &another_key,
            &support::http_client(),
        )
        .await;
        let requests_after = request_count(&radarr).await;
        let updated = sources::update(
            &db,
            source.id,
            ConfigurationInput::Servarr(with_api_key_again),
            &another_key,
            &support::http_client(),
        )
        .await
        .unwrap();

        let Err(UpdateError::InvalidConfiguration(error)) = refused else {
            panic!("{refused:?}");
        };
        assert_eq!(
            error,
            ConfigurationError::Servarr(ServarrConfigurationError::Connection(
                ConnectionError::InvalidApiKey
            ))
        );
        assert_eq!(requests_after, requests_before);
        assert_eq!(decrypted_api_key(&updated, &another_key), API_KEY);
    }
}

mod check_existing_source {
    use sqlx::PgPool;
    use watch_club::domain::sources::CheckExistingSourceError;
    use watch_club_test_macros::database_test;

    use super::*;

    #[database_test]
    async fn checks_the_app_with_the_sources_saved_api_key(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_radarr_source(&db, &radarr).await;

        let client = sources::check_existing_source(
            &db,
            source.id,
            &radarr.url(),
            None,
            &support::encryption_key(),
            &support::http_client(),
        )
        .await
        .unwrap();

        assert_eq!(client.list_root_folders().await.unwrap(), [ROOT_FOLDER]);
    }

    #[database_test]
    async fn checks_the_app_with_another_api_key(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let moved_radarr = FakeServarr::radarr_with_api_key("new-api-key").await;
        let source = create_radarr_source(&db, &radarr).await;
        let new_api_key = support::encryption_key().encrypt(&"new-api-key".into());

        let with_saved_key = sources::check_existing_source(
            &db,
            source.id,
            &moved_radarr.url(),
            None,
            &support::encryption_key(),
            &support::http_client(),
        )
        .await;
        let with_new_key = sources::check_existing_source(
            &db,
            source.id,
            &moved_radarr.url(),
            Some(new_api_key),
            &support::encryption_key(),
            &support::http_client(),
        )
        .await;

        assert!(
            matches!(
                with_saved_key,
                Err(CheckExistingSourceError::Connection(
                    ConnectionError::InvalidApiKey
                ))
            ),
            "{with_saved_key:?}"
        );
        assert!(with_new_key.is_ok(), "{with_new_key:?}");
    }

    #[database_test]
    async fn asks_for_the_api_key_again_when_another_key_encrypted_it(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_radarr_source(&db, &radarr).await;
        let requests_before = request_count(&radarr).await;

        let result = sources::check_existing_source(
            &db,
            source.id,
            &radarr.url(),
            None,
            &support::another_encryption_key(),
            &support::http_client(),
        )
        .await;

        assert!(
            matches!(
                result,
                Err(CheckExistingSourceError::Connection(
                    ConnectionError::InvalidApiKey
                ))
            ),
            "{result:?}"
        );
        assert_eq!(request_count(&radarr).await, requests_before);
    }
}
