use axum::http::StatusCode;
use serde_json::json;
use sqlx::PgPool;

use crate::support::Client;

#[sqlx::test]
async fn says_the_server_works(db: PgPool) {
    let response = Client::new(&db).get("/api/health").await;

    assert_eq!(response.status, StatusCode::NO_CONTENT, "{response:?}");
}

#[sqlx::test]
async fn says_the_server_cannot_reach_its_database(db: PgPool) {
    let mut client = Client::new(&db);
    db.close().await;

    let response = client.get("/api/health").await;

    assert_eq!(response.status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(
        response.body,
        json!({
            "code": "database_unreachable",
            "message": "the server can't reach its database",
        })
    );
}
