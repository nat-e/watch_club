use sqlx::PgPool;
use watch_club::domain::accounts::{self, Locale, Password, RedeemInvitationError, Username};
use watch_club_test_macros::database_test;

use crate::support;

#[database_test]
async fn people_who_redeem_it_at_once_stay_within_its_max_uses(db: PgPool) {
    let db = watch_club::db::instrument(db);
    support::create_invitation(&db, "FRIENDS", Some(1)).await;
    let redeem = |username| {
        let username = Username::parse(username).unwrap();
        let password = Password::parse("secret password".into()).unwrap();
        accounts::redeem_invitation(&db, "FRIENDS", username, password, Locale::EnUs)
    };

    let (ada, grace) = tokio::join!(redeem("ada"), redeem("grace"));

    let refused = [&ada, &grace]
        .into_iter()
        .filter(|redeemed| matches!(redeemed, Err(RedeemInvitationError::NotRedeemable)))
        .count();
    assert!(ada.is_ok() || grace.is_ok(), "{ada:?} {grace:?}");
    assert_eq!(refused, 1, "{ada:?} {grace:?}");
}
