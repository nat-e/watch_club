use axum::http::StatusCode;
use sqlx::PgPool;

use crate::support::{self, Client};

#[sqlx::test]
async fn needs_setup_until_the_instance_administrator_exists(db: PgPool) {
    let response = Client::new(&db).get("/api/instance").await;
    assert_eq!(response.status, StatusCode::OK);
    assert_eq!(response.body["needs_setup"], true);

    support::create_instance_administrator(&db).await;

    let response = Client::new(&db).get("/api/instance").await;
    assert_eq!(response.body["needs_setup"], false);
    assert_eq!(response.body["version"], env!("CARGO_PKG_VERSION"));
}
