use axum::http::StatusCode;
use sqlx::PgPool;

use crate::support::Client;

#[sqlx::test]
async fn unknown_paths_are_not_found_rather_than_the_web_app(db: PgPool) {
    for path in ["/api", "/api/", "/api/nothing-here"] {
        let response = Client::new(&db).get(path).await;

        assert_eq!(response.status, StatusCode::NOT_FOUND, "{path}");
    }
}
