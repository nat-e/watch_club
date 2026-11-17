use std::time::Duration;

use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use sqlx::{PgPool, postgres::PgPoolOptions};
use watch_club::domain::accounts::{
    self, CreateInstanceAdministratorError, Locale, Password, PasswordError, SessionToken, User,
    Username, UsernameError,
};
use watch_club::testing::database;

use crate::support::{self, PASSWORD};

/// Signs the User in with `PASSWORD`, and returns the token of the session it starts.
async fn new_session(db: &PgPool, user: &User) -> SessionToken {
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

    #[tokio::test]
    async fn is_false_until_setup() {
        let db = database().await;
        support::create_user(&db, "ada").await;

        let set_up = accounts::has_instance_administrator(&db).await.unwrap();

        assert!(!set_up);
    }

    #[tokio::test]
    async fn is_true_once_the_instance_administrator_exists() {
        let db = database().await;
        support::create_instance_administrator(&db).await;

        let set_up = accounts::has_instance_administrator(&db).await.unwrap();

        assert!(set_up);
    }
}

mod create_instance_administrator {
    use super::*;

    #[tokio::test]
    async fn creates_the_instance_administrator_and_signs_them_in() {
        let db = database().await;
        let (admin, token) = accounts::create_instance_administrator(
            &db,
            Username::parse("ada").unwrap(),
            Password::parse("secret password".into()).unwrap(),
            Locale::FrFr,
        )
        .await
        .unwrap();

        assert!(admin.is_instance_administrator);
        assert_eq!(admin.locale, Locale::FrFr);
        let session_user = accounts::session_user(&db, &token).await.unwrap();
        assert_eq!(session_user.as_ref(), Some(&admin));
        let (signed_in, _) = accounts::sign_in(&db, "ada", "secret password".into())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(signed_in, admin);
    }

    #[tokio::test]
    async fn fails_when_there_is_one_already() {
        let db = database().await;
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

    #[tokio::test]
    async fn fails_when_there_is_one_already_with_the_same_username() {
        let db = database().await;
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

    #[tokio::test]
    async fn fails_when_there_is_one_already_with_a_single_connection() {
        let database = database().await;
        let db = PgPoolOptions::new()
            .max_connections(1)
            .acquire_timeout(Duration::from_secs(2))
            .connect_with(database.connect_options().as_ref().clone())
            .await
            .unwrap();
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
}

mod sign_in {
    use super::*;

    #[tokio::test]
    async fn signs_in_the_user_with_this_password() {
        let db = database().await;
        let user = support::create_user(&db, "ada").await;

        let (signed_in, token) = accounts::sign_in(&db, " ada ", PASSWORD.into())
            .await
            .unwrap()
            .unwrap();

        assert_eq!(signed_in, user);
        let session_user = accounts::session_user(&db, &token).await.unwrap();
        assert_eq!(session_user, Some(user));
    }

    #[tokio::test]
    async fn gives_each_device_its_own_token() {
        let db = database().await;
        let user = support::create_user(&db, "ada").await;

        let phone = new_session(&db, &user).await;
        let laptop = new_session(&db, &user).await;

        assert_ne!(phone.encode(), laptop.encode());
    }

    #[tokio::test]
    async fn is_none_for_a_wrong_password() {
        let db = database().await;
        support::create_user(&db, "ada").await;

        let signed_in = accounts::sign_in(&db, "ada", "wrong password".into())
            .await
            .unwrap();

        assert!(signed_in.is_none());
    }

    #[tokio::test]
    async fn is_none_for_an_unknown_username() {
        let db = database().await;
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

    #[tokio::test]
    async fn is_none_for_a_token_that_never_signed_in() {
        let db = database().await;
        let token = SessionToken::decode(&"A".repeat(43)).unwrap();

        let signed_in = accounts::session_user(&db, &token).await.unwrap();

        assert_eq!(signed_in, None);
    }

    #[tokio::test]
    async fn is_none_once_the_session_expired() {
        let db = database().await;
        let user = support::create_user(&db, "ada").await;
        let token = new_session(&db, &user).await;
        support::expire_sessions(&db, user.id).await;

        let signed_in = accounts::session_user(&db, &token).await.unwrap();

        assert_eq!(signed_in, None);
    }
}

mod sign_out {
    use super::*;

    #[tokio::test]
    async fn signs_out_this_device_only() {
        let db = database().await;
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

    #[tokio::test]
    async fn deletes_only_the_expired_sessions() {
        let db = database().await;
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
