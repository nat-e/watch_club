use axum::http::StatusCode;
use sqlx::PgPool;

use crate::support::Client;

#[sqlx::test]
async fn unknown_paths_are_not_found_rather_than_the_web_app(db: PgPool) {
    let mut client = Client::new(&db);
    for path in ["/api", "/api/", "/api/nothing-here"] {
        let get = client.get(path).await;
        let post = client.post_without_body(path).await;

        assert_eq!(get.status, StatusCode::NOT_FOUND, "GET {path}");
        assert_eq!(post.status, StatusCode::NOT_FOUND, "POST {path}");
    }
}

#[sqlx::test]
async fn only_get_and_head_reach_the_web_app(db: PgPool) {
    let response = Client::new(&db).post_without_body("/index.html").await;

    assert_eq!(response.status, StatusCode::METHOD_NOT_ALLOWED);
}
