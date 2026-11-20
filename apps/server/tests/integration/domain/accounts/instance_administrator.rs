use std::collections::BTreeSet;

use sqlx::PgPool;
use watch_club::domain::accounts::{
    instance_administrator::{self, CreateInstanceAdministratorError},
    preferences::{AudioLanguage, Locale, TrackLanguage, UserPreferences},
    sessions,
    users::{Password, Username},
};
use watch_club_test_macros::database_test;

use crate::support;

mod exists {
    use super::*;

    #[database_test]
    async fn is_false_until_setup(db: PgPool) {
        let db = watch_club::db::instrument(db);
        support::create_user(&db, "ada").await;

        let set_up = instance_administrator::exists(&db).await.unwrap();

        assert!(!set_up);
    }

    #[database_test]
    async fn is_true_once_the_instance_administrator_exists(db: PgPool) {
        let db = watch_club::db::instrument(db);
        support::create_instance_administrator(&db).await;

        let set_up = instance_administrator::exists(&db).await.unwrap();

        assert!(set_up);
    }
}

mod create {
    use super::*;

    #[database_test]
    async fn gives_them_subtitles_in_their_language_except_when_the_audio_is_in_it(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let (admin, _) = instance_administrator::create(
            &db,
            Username::parse("ada").unwrap(),
            Password::parse("secret password".into()).unwrap(),
            Locale::FrFr,
        )
        .await
        .unwrap();

        assert_eq!(
            admin.preferences,
            UserPreferences {
                locale: Locale::FrFr,
                audio_language: AudioLanguage::Original,
                subtitle_language: Some(TrackLanguage::Fr),
                languages_without_subtitles: BTreeSet::from([TrackLanguage::Fr]),
            }
        );
    }

    #[database_test]
    async fn creates_the_instance_administrator_and_signs_them_in(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let (admin, token) = instance_administrator::create(
            &db,
            Username::parse("ada").unwrap(),
            Password::parse("secret password".into()).unwrap(),
            Locale::FrFr,
        )
        .await
        .unwrap();

        assert!(admin.is_instance_administrator);
        assert_eq!(admin.preferences.locale, Locale::FrFr);
        let current_user = sessions::get_current_user(&db, &token).await.unwrap();
        assert_eq!(current_user.as_ref(), Some(&admin));
        let (signed_in, _) = sessions::sign_in(&db, "ada", "secret password".into())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(signed_in, admin);
    }

    #[database_test]
    async fn fails_when_there_is_one_already(db: PgPool) {
        let db = watch_club::db::instrument(db);
        support::create_instance_administrator(&db).await;

        let created = instance_administrator::create(
            &db,
            Username::parse("ada").unwrap(),
            Password::parse("secret password".into()).unwrap(),
            Locale::EnUs,
        )
        .await;

        assert!(matches!(
            created,
            Err(CreateInstanceAdministratorError::AlreadyExists)
        ));
    }

    #[database_test]
    async fn fails_when_there_is_one_already_with_the_same_username(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let admin = support::create_instance_administrator(&db).await;

        let created = instance_administrator::create(
            &db,
            Username::parse(&admin.username).unwrap(),
            Password::parse("secret password".into()).unwrap(),
            Locale::EnUs,
        )
        .await;

        assert!(matches!(
            created,
            Err(CreateInstanceAdministratorError::AlreadyExists)
        ));
    }
}
