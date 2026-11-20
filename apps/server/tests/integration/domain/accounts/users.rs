use sqlx::PgPool;
use watch_club::domain::accounts::users::{
    self, ParsePasswordError, ParseUsernameError, Password, ResetPasswordError, Username,
};
use watch_club_test_macros::database_test;

use crate::support::{self, PASSWORD};

mod username {
    use super::*;

    #[test]
    fn accepts_lowercase_letters_digits_and_underscores() {
        assert!(Username::parse(" ada_42 ").is_ok());
    }

    #[test]
    fn rejects_usernames_that_break_the_rules() {
        assert_eq!(Username::parse("  "), Err(ParseUsernameError::Missing));
        assert_eq!(
            Username::parse("ad"),
            Err(ParseUsernameError::TooShort { min: 3 })
        );
        assert_eq!(
            Username::parse(&"a".repeat(31)),
            Err(ParseUsernameError::TooLong { max: 30 })
        );
        assert_eq!(
            Username::parse("Ada"),
            Err(ParseUsernameError::InvalidCharacters)
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
            Some(ParsePasswordError::Missing)
        );
        assert_eq!(
            Password::parse("1234567".into()).err(),
            Some(ParsePasswordError::TooShort { min: 8 })
        );
    }

    #[test]
    fn debug_hides_the_password() {
        let password = Password::parse(PASSWORD.into()).unwrap();

        assert!(!format!("{password:?}").contains(PASSWORD));
    }
}

mod reset_password {
    use super::*;

    #[database_test]
    async fn a_password_reset_link_works_once_even_for_two_requests_at_once(db: PgPool) {
        let db = watch_club::db::instrument(db);
        let user = support::create_user(&db, "ada").await;
        let token = support::create_password_reset_link(&db, user.id).await;
        let reset = |password: &str| {
            let password = Password::parse(password.into()).unwrap();
            users::reset_password(&db, &token, password)
        };

        let (first, second) = tokio::join!(reset("first password"), reset("second password"));

        let refused = [&first, &second]
            .into_iter()
            .filter(|reset| matches!(reset, Err(ResetPasswordError::LinkNoLongerWorks)))
            .count();
        assert!(first.is_ok() || second.is_ok(), "{first:?} {second:?}");
        assert_eq!(refused, 1, "{first:?} {second:?}");
    }
}
