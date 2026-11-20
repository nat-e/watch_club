//! Radarr, Sonarr and Sportarr Sources: creating and updating them, without calling the app, and
//! the API key they keep and decrypt. `connection` tests `test_servarr_connection`, which calls the apps.

mod connection;

use secrecy::ExposeSecret;
use watch_club::{
    domain::sources::{self, QualityProfile, ServarrApp, Source, SourceConfiguration},
    utils::{encryption::EncryptionKey, filesystem::AbsoluteFolder},
};

use super::{FOLDER, create_app_source};
use crate::support::{self, FakeServarr, fake_servarr::ROOT_FOLDER};

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
    use watch_club::domain::{contents::MediaType, sources::SourceType};
    use watch_club_test_macros::database_test;

    use super::*;

    #[database_test]
    async fn creates_a_source_of_each_app_without_calling_it(db: PgPool) {
        let db = watch_club::db::instrument(db);

        for (fake, source_type, media_type) in [
            (
                FakeServarr::radarr().await,
                SourceType::Radarr,
                MediaType::Movie,
            ),
            (
                FakeServarr::sonarr().await,
                SourceType::Sonarr,
                MediaType::TvShowEpisode,
            ),
            (
                FakeServarr::sportarr().await,
                SourceType::Sportarr,
                MediaType::SportsEvent,
            ),
        ] {
            let configuration = fake.source_configuration();

            let source = sources::create_servarr_source(&db, configuration.clone())
                .await
                .unwrap();

            assert_eq!(
                source.configuration,
                SourceConfiguration::Servarr(configuration)
            );
            assert_eq!(source.configuration.source_type(), source_type);
            assert_eq!(source.configuration.media_type(), media_type);
            // The connection test checked the app before
            assert_eq!(request_count(&fake).await, 0);
        }
        assert_eq!(sources::list(&db).await.unwrap().len(), 3);
    }
}

mod decrypt_api_key {
    use watch_club::domain::sources::ConnectionError;

    use super::*;
    use crate::support::fake_servarr::API_KEY;

    #[tokio::test]
    async fn decrypts_the_api_key_with_the_key_that_encrypted_it() {
        let configuration = FakeServarr::radarr().await.source_configuration();

        let api_key = configuration.decrypt_api_key(&support::encryption_key());

        assert_eq!(api_key.unwrap().expose_secret(), API_KEY);
    }

    #[tokio::test]
    async fn blames_the_api_key_when_another_key_encrypted_it() {
        let configuration = FakeServarr::radarr().await.source_configuration();

        let api_key = configuration.decrypt_api_key(&support::another_encryption_key());

        assert_eq!(api_key.err(), Some(ConnectionError::InvalidApiKey));
    }
}

mod update {
    use sqlx::PgPool;
    use watch_club::domain::sources::{ServarrConfigurationUpdate, UpdateError};
    use watch_club_test_macros::database_test;

    use super::*;
    use crate::domain::sources::{create_movies_folder, deleted_source_id};

    /// Returns the update that gives a Source of this fake app the configuration it was created
    /// with, without an API key.
    fn configuration_update(app: &FakeServarr) -> ServarrConfigurationUpdate {
        ServarrConfigurationUpdate {
            url: app.url().parse().unwrap(),
            api_key: None,
            quality_profile: QualityProfile {
                id: 4,
                name: "HD-1080p".to_owned(),
            },
            root_folder_path: ROOT_FOLDER.to_owned(),
            local_root_folder_path: None,
        }
    }

    #[database_test]
    async fn changes_the_apps_configuration(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_app_source(&db, &radarr).await;
        let any = QualityProfile {
            id: 1,
            name: "Any".to_owned(),
        };
        let folder = AbsoluteFolder::parse(FOLDER).await.unwrap();
        let configuration = ServarrConfigurationUpdate {
            quality_profile: any.clone(),
            local_root_folder_path: Some(folder.clone()),
            api_key: Some(support::encryption_key().encrypt(&"new-api-key".into())),
            ..configuration_update(&radarr)
        };

        let updated = sources::update_servarr_source(&db, source.id, configuration)
            .await
            .unwrap();

        let SourceConfiguration::Servarr(saved) = &updated.configuration else {
            panic!("{updated:?}");
        };
        assert_eq!(updated.id, source.id);
        assert_eq!(saved.app, ServarrApp::Radarr);
        assert_eq!(saved.quality_profile, any);
        assert_eq!(saved.local_root_folder_path, Some(folder));
        assert_eq!(
            decrypted_api_key(&updated, &support::encryption_key()),
            "new-api-key"
        );
        assert_eq!(sources::list(&db).await.unwrap(), [updated]);
    }

    #[database_test]
    async fn keeps_the_saved_api_key_without_a_new_one(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_app_source(&db, &radarr).await;

        let updated = sources::update_servarr_source(&db, source.id, configuration_update(&radarr))
            .await
            .unwrap();

        assert_eq!(updated, source);
        assert_eq!(sources::list(&db).await.unwrap(), [source]);
    }

    #[database_test]
    async fn updates_only_an_apps_source(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let folder = create_movies_folder(&db, FOLDER).await;
        let deleted = deleted_source_id(&db).await;

        for id in [folder.id, deleted] {
            let result =
                sources::update_servarr_source(&db, id, configuration_update(&radarr)).await;

            assert!(
                matches!(result, Err(UpdateError::SourceNotFound)),
                "{result:?}"
            );
        }
        assert_eq!(sources::list(&db).await.unwrap(), [folder]);
    }
}
