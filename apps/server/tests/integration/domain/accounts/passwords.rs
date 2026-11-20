use sqlx::PgPool;
use watch_club::domain::accounts::{self, Password, ResetPasswordError};
use watch_club_test_macros::database_test;

use crate::support;

#[database_test]
async fn a_password_reset_link_works_once_even_for_two_requests_at_once(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let user = support::create_user(&db, "ada").await;
    let token = support::create_password_reset_link(&db, user.id).await;
    let reset = |password: &str| {
        let password = Password::parse(password.into()).unwrap();
        accounts::reset_password(&db, &token, password)
    };

    let (first, second) = tokio::join!(reset("first password"), reset("second password"));

    let refused = [&first, &second]
        .into_iter()
        .filter(|reset| matches!(reset, Err(ResetPasswordError::LinkNoLongerWorks)))
        .count();
    assert!(first.is_ok() || second.is_ok(), "{first:?} {second:?}");
    assert_eq!(refused, 1, "{first:?} {second:?}");
}
