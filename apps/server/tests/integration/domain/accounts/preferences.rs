use std::collections::BTreeSet;

use sqlx::PgPool;
use watch_club::domain::accounts::{self, AudioLanguage, Locale, TrackLanguage, UserPreferences};
use watch_club_test_macros::database_test;

use crate::support::{self, PASSWORD};

mod save_preferences {
    use super::*;

    #[database_test]
    async fn saves_the_users_preferences(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let user = support::create_user(&db, "ada").await;
        let preferences = UserPreferences {
            locale: Locale::FrFr,
            audio_language: AudioLanguage::En,
            subtitle_language: None,
            languages_without_subtitles: BTreeSet::from([TrackLanguage::En, TrackLanguage::Fr]),
        };

        let saved = accounts::save_preferences(&db, user.id, &preferences)
            .await
            .unwrap();

        assert_eq!(saved.preferences, preferences);
        let (signed_in, _) = accounts::sign_in(&db, "ada", PASSWORD.into())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(signed_in, saved);
    }
}
