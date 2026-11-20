use std::collections::BTreeSet;

use sqlx::PgPool;
use watch_club::domain::accounts::{
    preferences::{self, AudioLanguage, Locale, TrackLanguage, UserPreferences},
    sessions,
};
use watch_club_test_macros::database_test;

use crate::support::{self, PASSWORD};

mod save {
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

        let saved = preferences::save(&db, user.id, &preferences).await.unwrap();

        assert_eq!(saved.preferences, preferences);
        let (signed_in, _) = sessions::sign_in(&db, "ada", PASSWORD.into())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(signed_in, saved);
    }
}
