use std::collections::BTreeSet;

use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use sqlx::PgPool;
use watch_club::db::Pool;
use watch_club::domain::accounts::{
    self, AudioLanguage, CreateInstanceAdministratorError, CurrentUser, Locale, Password,
    PasswordError, SessionToken, TrackLanguage, UserPreferences, Username, UsernameError,
};
use watch_club_test_macros::database_test;

use crate::support::{self, PASSWORD};

/// Signs the User in with `PASSWORD`, and returns the token of the session it starts.
async fn new_session(db: &Pool, user: &CurrentUser) -> SessionToken {
    let (_, token) = accounts::sign_in(db, &user.username, PASSWORD.into())
        .await
        .unwrap()
        .unwrap();
    token
}

mod username {
    use super::*;

    #[test]
    fn accepts_lowercase_letters_digits_and_underscores() {
        assert!(Username::parse(" ada_42 ").is_ok());
    }

    #[test]
    fn rejects_usernames_that_break_the_rules() {
        assert_eq!(Username::parse("  "), Err(UsernameError::Missing));
        assert_eq!(
            Username::parse("ad"),
            Err(UsernameError::TooShort { min: 3 })
        );
        assert_eq!(
            Username::parse(&"a".repeat(31)),
            Err(UsernameError::TooLong { max: 30 })
        );
        assert_eq!(
            Username::parse("Ada"),
            Err(UsernameError::InvalidCharacters)
        );
    }
}

mod password {
    use super::*;

    #[test]
    fn accepts_8_characters() {
        assert!(Password::parse("12345678".into()).is_ok());
    }

    #[test]
    fn rejects_short_passwords() {
        assert_eq!(
            Password::parse("".into()).err(),
            Some(PasswordError::Missing)
        );
        assert_eq!(
            Password::parse("1234567".into()).err(),
            Some(PasswordError::TooShort { min: 8 })
        );
    }

    #[test]
    fn debug_hides_the_password() {
        let password = Password::parse(PASSWORD.into()).unwrap();

        assert!(!format!("{password:?}").contains(PASSWORD));
    }
}

mod has_instance_administrator {
    use super::*;

    #[database_test]
    async fn is_false_until_setup(db: PgPool) {
        let db = watch_club::db::instrument(db);
        support::create_user(&db, "ada").await;

        let set_up = accounts::has_instance_administrator(&db).await.unwrap();

        assert!(!set_up);
    }

    #[database_test]
    async fn is_true_once_the_instance_administrator_exists(db: PgPool) {
        let db = watch_club::db::instrument(db);
        support::create_instance_administrator(&db).await;

        let set_up = accounts::has_instance_administrator(&db).await.unwrap();

        assert!(set_up);
    }
}

mod create_instance_administrator {
    use super::*;

    #[database_test]
    async fn gives_them_subtitles_in_their_language_except_when_the_audio_is_in_it(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let (admin, _) = accounts::create_instance_administrator(
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
        let (admin, token) = accounts::create_instance_administrator(
            &db,
            Username::parse("ada").unwrap(),
            Password::parse("secret password".into()).unwrap(),
            Locale::FrFr,
        )
        .await
        .unwrap();

        assert!(admin.is_instance_administrator);
        assert_eq!(admin.preferences.locale, Locale::FrFr);
        let session_user = accounts::session_user(&db, &token).await.unwrap();
        assert_eq!(session_user.as_ref(), Some(&admin));
        let (signed_in, _) = accounts::sign_in(&db, "ada", "secret password".into())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(signed_in, admin);
    }

    #[database_test]
    async fn fails_when_there_is_one_already(db: PgPool) {
        let db = watch_club::db::instrument(db);
        support::create_instance_administrator(&db).await;

        let created = accounts::create_instance_administrator(
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

        let created = accounts::create_instance_administrator(
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

mod sign_in {
    use super::*;

    #[database_test]
    async fn signs_in_the_user_with_this_password(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let user = support::create_user(&db, "ada").await;

        let (signed_in, token) = accounts::sign_in(&db, " ada ", PASSWORD.into())
            .await
            .unwrap()
            .unwrap();

        assert_eq!(signed_in, user);
        let session_user = accounts::session_user(&db, &token).await.unwrap();
        assert_eq!(session_user, Some(user));
    }

    #[database_test]
    async fn gives_each_device_its_own_token(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let user = support::create_user(&db, "ada").await;

        let phone = new_session(&db, &user).await;
        let laptop = new_session(&db, &user).await;

        assert_ne!(phone.encode(), laptop.encode());
    }

    #[database_test]
    async fn is_none_for_a_wrong_password(db: PgPool) {
        let db = watch_club::db::instrument(db);
        support::create_user(&db, "ada").await;

        let signed_in = accounts::sign_in(&db, "ada", "wrong password".into())
            .await
            .unwrap();

        assert!(signed_in.is_none());
    }

    #[database_test]
    async fn is_none_for_an_unknown_username(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let signed_in = accounts::sign_in(&db, "ada", PASSWORD.into())
            .await
            .unwrap();

        assert!(signed_in.is_none());
    }
}

mod session_token {
    use super::*;

    #[test]
    fn decode_rejects_text_that_is_not_a_token() {
        assert!(SessionToken::decode("").is_none());
        assert!(SessionToken::decode("not base64!").is_none());
        assert!(SessionToken::decode(&URL_SAFE_NO_PAD.encode([0; 31])).is_none());
        assert!(SessionToken::decode(&URL_SAFE_NO_PAD.encode([0; 33])).is_none());
    }

    #[test]
    fn debug_hides_the_token() {
        let text = URL_SAFE_NO_PAD.encode([7; 32]);
        let token = SessionToken::decode(&text).unwrap();

        let debug = format!("{token:?}");
        // Neither as text nor as its bytes, which are all 7s
        assert!(!debug.contains(&text) && !debug.contains('7'));
    }
}

mod session_user {
    use super::*;

    #[database_test]
    async fn is_none_for_a_token_that_never_signed_in(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let token = SessionToken::decode(&"A".repeat(43)).unwrap();

        let signed_in = accounts::session_user(&db, &token).await.unwrap();

        assert_eq!(signed_in, None);
    }

    #[database_test]
    async fn is_none_once_the_session_expired(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let user = support::create_user(&db, "ada").await;
        let token = new_session(&db, &user).await;
        support::expire_sessions(&db, user.id).await;

        let signed_in = accounts::session_user(&db, &token).await.unwrap();

        assert_eq!(signed_in, None);
    }
}

mod sign_out {
    use super::*;

    #[database_test]
    async fn signs_out_this_device_only(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let user = support::create_user(&db, "ada").await;
        let phone = new_session(&db, &user).await;
        let laptop = new_session(&db, &user).await;

        accounts::sign_out(&db, &phone).await.unwrap();

        assert_eq!(accounts::session_user(&db, &phone).await.unwrap(), None);
        assert_eq!(
            accounts::session_user(&db, &laptop).await.unwrap(),
            Some(user)
        );
    }
}

mod delete_expired_sessions {
    use super::*;

    #[database_test]
    async fn deletes_only_the_expired_sessions(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let ada = support::create_user(&db, "ada").await;
        let bob = support::create_user(&db, "bob").await;
        new_session(&db, &ada).await;
        new_session(&db, &ada).await;
        let bobs = new_session(&db, &bob).await;
        support::expire_sessions(&db, ada.id).await;

        let deleted = accounts::delete_expired_sessions(&db).await.unwrap();

        assert_eq!(deleted, 2);
        let left = sqlx::query_scalar!(r#"SELECT count(*) AS "count!" FROM sessions"#)
            .fetch_one(&db)
            .await
            .unwrap();
        assert_eq!(left, 1);
        assert_eq!(accounts::session_user(&db, &bobs).await.unwrap(), Some(bob));
    }
}
