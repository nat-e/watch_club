use std::time::Duration;

use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use sqlx::{
    PgPool,
    postgres::{PgConnectOptions, PgPoolOptions},
};
use watch_club::domain::accounts::{
    self, CreateInstanceAdministratorError, Locale, Password, PasswordError, SessionToken, User,
    Username, UsernameError,
};

use crate::support::{self, PASSWORD};

/// Signs the User in with `PASSWORD`, and returns the token of the session it starts.
async fn new_session(db: &PgPool, user: &User) -> SessionToken {
    let (_, token) = accounts::sign_in(db, &user.username, PASSWORD.to_owned())
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
        assert!(Password::parse("12345678".to_owned()).is_ok());
    }

    #[test]
    fn rejects_short_passwords() {
        assert_eq!(
            Password::parse(String::new()).err(),
            Some(PasswordError::Missing)
        );
        assert_eq!(
            Password::parse("1234567".to_owned()).err(),
            Some(PasswordError::TooShort { min: 8 })
        );
    }

    #[test]
    fn debug_hides_the_password() {
        let password = Password::parse(PASSWORD.to_owned()).unwrap();

        assert_eq!(format!("{password:?}"), "Password(…)");
    }
}

mod has_instance_administrator {
    use super::*;

    #[sqlx::test]
    async fn is_false_until_setup(db: PgPool) {
        support::create_user(&db, "ada").await;

        let set_up = accounts::has_instance_administrator(&db).await.unwrap();

        assert!(!set_up);
    }

    #[sqlx::test]
    async fn is_true_once_the_instance_administrator_exists(db: PgPool) {
        support::create_instance_administrator(&db).await;

        let set_up = accounts::has_instance_administrator(&db).await.unwrap();

        assert!(set_up);
    }
}

mod create_instance_administrator {
    use super::*;

    #[sqlx::test]
    async fn creates_the_instance_administrator_and_signs_them_in(db: PgPool) {
        let (admin, token) = accounts::create_instance_administrator(
            &db,
            Username::parse("ada").unwrap(),
            Password::parse("secret password".to_owned()).unwrap(),
            Locale::FrFr,
        )
        .await
        .unwrap();

        assert!(admin.is_instance_administrator);
        assert_eq!(admin.locale, Locale::FrFr);
        let session_user = accounts::session_user(&db, &token).await.unwrap();
        assert_eq!(session_user.as_ref(), Some(&admin));
        let (signed_in, _) = accounts::sign_in(&db, "ada", "secret password".to_owned())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(signed_in, admin);
    }

    #[sqlx::test]
    async fn fails_when_there_is_one_already(db: PgPool) {
        support::create_instance_administrator(&db).await;

        let created = accounts::create_instance_administrator(
            &db,
            Username::parse("ada").unwrap(),
            Password::parse("secret password".to_owned()).unwrap(),
            Locale::EnUs,
        )
        .await;

        assert!(matches!(
            created,
            Err(CreateInstanceAdministratorError::AlreadyExists)
        ));
    }

    #[sqlx::test]
    async fn fails_when_there_is_one_already_with_the_same_username(db: PgPool) {
        let admin = support::create_instance_administrator(&db).await;

        let created = accounts::create_instance_administrator(
            &db,
            Username::parse(&admin.username).unwrap(),
            Password::parse("secret password".to_owned()).unwrap(),
            Locale::EnUs,
        )
        .await;

        assert!(matches!(
            created,
            Err(CreateInstanceAdministratorError::AlreadyExists)
        ));
    }

    #[sqlx::test]
    async fn fails_when_there_is_one_already_with_a_single_connection(
        pool: PgPoolOptions,
        connection: PgConnectOptions,
    ) {
        let db = pool
            .max_connections(1)
            .acquire_timeout(Duration::from_secs(2))
            .connect_with(connection)
            .await
            .unwrap();
        support::create_instance_administrator(&db).await;

        let created = accounts::create_instance_administrator(
            &db,
            Username::parse("ada").unwrap(),
            Password::parse("secret password".to_owned()).unwrap(),
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

    #[sqlx::test]
    async fn signs_in_the_user_with_this_password(db: PgPool) {
        let user = support::create_user(&db, "ada").await;

        let (signed_in, token) = accounts::sign_in(&db, " ada ", PASSWORD.to_owned())
            .await
            .unwrap()
            .unwrap();

        assert_eq!(signed_in, user);
        let session_user = accounts::session_user(&db, &token).await.unwrap();
        assert_eq!(session_user, Some(user));
    }

    #[sqlx::test]
    async fn gives_each_device_its_own_token(db: PgPool) {
        let user = support::create_user(&db, "ada").await;

        let phone = new_session(&db, &user).await;
        let laptop = new_session(&db, &user).await;

        assert_ne!(phone, laptop);
    }

    #[sqlx::test]
    async fn is_none_for_a_wrong_password(db: PgPool) {
        support::create_user(&db, "ada").await;

        let signed_in = accounts::sign_in(&db, "ada", "wrong password".to_owned())
            .await
            .unwrap();

        assert_eq!(signed_in, None);
    }

    #[sqlx::test]
    async fn is_none_for_an_unknown_username(db: PgPool) {
        let signed_in = accounts::sign_in(&db, "ada", PASSWORD.to_owned())
            .await
            .unwrap();

        assert_eq!(signed_in, None);
    }
}

mod session_token {
    use super::*;

    #[test]
    fn decode_rejects_text_that_is_not_a_token() {
        assert_eq!(SessionToken::decode(""), None);
        assert_eq!(SessionToken::decode("not base64!"), None);
        assert_eq!(SessionToken::decode(&URL_SAFE_NO_PAD.encode([0; 31])), None);
        assert_eq!(SessionToken::decode(&URL_SAFE_NO_PAD.encode([0; 33])), None);
    }

    #[test]
    fn debug_hides_the_token() {
        let token = SessionToken::decode(&URL_SAFE_NO_PAD.encode([7; 32])).unwrap();

        assert_eq!(format!("{token:?}"), "SessionToken(…)");
    }
}

mod session_user {
    use super::*;

    #[sqlx::test]
    async fn is_none_for_a_token_that_never_signed_in(db: PgPool) {
        let token = SessionToken::decode(&"A".repeat(43)).unwrap();

        let signed_in = accounts::session_user(&db, &token).await.unwrap();

        assert_eq!(signed_in, None);
    }

    #[sqlx::test]
    async fn is_none_once_the_session_expired(db: PgPool) {
        let user = support::create_user(&db, "ada").await;
        let token = new_session(&db, &user).await;
        support::expire_sessions(&db, user.id).await;

        let signed_in = accounts::session_user(&db, &token).await.unwrap();

        assert_eq!(signed_in, None);
    }
}

mod sign_out {
    use super::*;

    #[sqlx::test]
    async fn signs_out_this_device_only(db: PgPool) {
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
