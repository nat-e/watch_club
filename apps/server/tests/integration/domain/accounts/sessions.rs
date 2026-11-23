use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use sqlx::PgPool;
use watch_club::db::Pool;
use watch_club::domain::accounts::{
    sessions::{self, SessionToken, SignInError},
    users::CurrentUser,
};
use watch_club_test_macros::database_test;

use crate::support::{self, PASSWORD};

/// Signs the User in with `PASSWORD`, and returns the token of the session it starts.
async fn new_session(db: &Pool, user: &CurrentUser) -> SessionToken {
    let (_, token) = sessions::sign_in(db, &user.username, PASSWORD.into())
        .await
        .unwrap();
    token
}

mod sign_in {
    use super::*;

    #[database_test]
    async fn signs_in_the_user_with_this_password(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let user = support::create_user(&db, "ada").await;

        let (signed_in, token) = sessions::sign_in(&db, " ada ", PASSWORD.into())
            .await
            .unwrap();

        assert_eq!(signed_in, user);
        let current_user = sessions::get_current_user(&db, &token).await.unwrap();
        assert_eq!(current_user, Some(user));
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
    async fn fails_for_a_wrong_password(db: PgPool) {
        let db = watch_club::db::instrument(db);
        support::create_user(&db, "ada").await;

        let signed_in = sessions::sign_in(&db, "ada", "wrong password".into()).await;

        assert!(
            matches!(signed_in, Err(SignInError::WrongCredentials)),
            "{signed_in:?}"
        );
    }

    #[database_test]
    async fn fails_for_an_unknown_username(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let signed_in = sessions::sign_in(&db, "ada", PASSWORD.into()).await;

        assert!(
            matches!(signed_in, Err(SignInError::WrongCredentials)),
            "{signed_in:?}"
        );
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

mod get_current_user {
    use super::*;

    #[database_test]
    async fn is_none_for_a_token_that_never_signed_in(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let token = SessionToken::decode(&"A".repeat(43)).unwrap();

        let signed_in = sessions::get_current_user(&db, &token).await.unwrap();

        assert_eq!(signed_in, None);
    }

    #[database_test]
    async fn is_none_once_the_session_expired(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let user = support::create_user(&db, "ada").await;
        let token = new_session(&db, &user).await;
        support::expire_sessions(&db, user.id).await;

        let signed_in = sessions::get_current_user(&db, &token).await.unwrap();

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

        sessions::sign_out(&db, &phone).await.unwrap();

        assert_eq!(sessions::get_current_user(&db, &phone).await.unwrap(), None);
        assert_eq!(
            sessions::get_current_user(&db, &laptop).await.unwrap(),
            Some(user)
        );
    }
}

mod delete_expired {
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

        let deleted = sessions::delete_expired(&db).await.unwrap();

        assert_eq!(deleted, 2);
        let left = sqlx::query_scalar!(r#"SELECT count(*) AS "count!" FROM sessions"#)
            .fetch_one(&db)
            .await
            .unwrap();
        assert_eq!(left, 1);
        assert_eq!(
            sessions::get_current_user(&db, &bobs).await.unwrap(),
            Some(bob)
        );
    }
}
