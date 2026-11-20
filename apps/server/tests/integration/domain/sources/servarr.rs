//! Radarr, Sonarr and Sportarr Sources: creating and updating them, without calling the app, and
//! the API key they keep encrypted. `connection` tests the connection to the apps, which calls them.

mod connection;

use secrecy::ExposeSecret;
use watch_club::{
    db::Pool,
    domain::sources::{
        self, Source,
        servarr::{self, QualityProfile, ServarrApp},
    },
    utils::filesystem::AbsoluteFolder,
};

use super::{FOLDER, create_app_source};
use crate::support::{self, FakeServarr, fake_servarr::API_KEY};

/// Returns the API key the Source saved, decrypted with the tests' key.
async fn saved_api_key(db: &Pool, source: &Source) -> String {
    let saved = support::saved_api_key(db, &source.id().to_string()).await;
    let api_key = support::encryption_key().decrypt(&saved).unwrap();
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
            let source = servarr::create(
                &db,
                &support::encryption_key(),
                fake.app(),
                fake.source_configuration(),
                &fake.api_key(),
            )
            .await
            .unwrap();

            assert_eq!(
                source,
                Source::Servarr {
                    id: source.id(),
                    app: fake.app(),
                    configuration: fake.source_configuration(),
                }
            );
            assert_eq!(source.source_type(), source_type);
            assert_eq!(source.media_type(), media_type);
            assert_eq!(saved_api_key(&db, &source).await, API_KEY);
            // The connection test checked the app before
            assert_eq!(request_count(&fake).await, 0);
        }
        assert_eq!(sources::list(&db).await.unwrap().len(), 3);
    }
}

mod update {
    use sqlx::PgPool;
    use watch_club::domain::sources::UpdateSourceError;
    use watch_club_test_macros::database_test;

    use super::*;
    use crate::domain::sources::{create_movies_folder, deleted_source_id};

    #[database_test]
    async fn changes_the_apps_configuration(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_app_source(&db, &radarr).await;
        let mut configuration = radarr.source_configuration();
        configuration.quality_profile = QualityProfile {
            id: 1,
            name: "Any".to_owned(),
        };
        configuration.local_root_folder_path = Some(AbsoluteFolder::parse(FOLDER).await.unwrap());

        let updated = servarr::update(
            &db,
            &support::encryption_key(),
            source.id(),
            configuration.clone(),
            Some(&"new-api-key".into()),
        )
        .await
        .unwrap();

        let expected = Source::Servarr {
            id: source.id(),
            app: ServarrApp::Radarr,
            configuration,
        };
        assert_eq!(updated, expected);
        assert_eq!(saved_api_key(&db, &updated).await, "new-api-key");
        assert_eq!(sources::list(&db).await.unwrap(), [expected]);
    }

    #[database_test]
    async fn keeps_the_saved_api_key_without_a_new_one(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let source = create_app_source(&db, &radarr).await;

        let updated = servarr::update(
            &db,
            &support::encryption_key(),
            source.id(),
            radarr.source_configuration(),
            None,
        )
        .await
        .unwrap();

        assert_eq!(updated, source);
        assert_eq!(saved_api_key(&db, &source).await, API_KEY);
        assert_eq!(sources::list(&db).await.unwrap(), [source]);
    }

    #[database_test]
    async fn updates_only_an_apps_source(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let radarr = FakeServarr::radarr().await;
        let folder = create_movies_folder(&db, FOLDER).await;
        let deleted = deleted_source_id(&db).await;

        for id in [folder.id(), deleted] {
            let result = servarr::update(
                &db,
                &support::encryption_key(),
                id,
                radarr.source_configuration(),
                None,
            )
            .await;

            assert!(
                matches!(result, Err(UpdateSourceError::NotFound)),
                "{result:?}"
            );
        }
        assert_eq!(sources::list(&db).await.unwrap(), [folder]);
    }
}
