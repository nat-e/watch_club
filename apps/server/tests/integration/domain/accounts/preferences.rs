use watch_club::{
    domain::accounts::{self, Locale},
    testing::database,
};

use crate::support::{self, PASSWORD};

mod change_locale {
    use super::*;

    #[tokio::test]
    async fn changes_the_users_locale() {
        let db = database().await;
        let user = support::create_user(&db, "ada").await;

        let changed = accounts::change_locale(&db, user.id, Locale::FrFr)
            .await
            .unwrap();

        assert_eq!(changed.locale, Locale::FrFr);
        let (signed_in, _) = accounts::sign_in(&db, "ada", PASSWORD.into())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(signed_in, changed);
    }
}
