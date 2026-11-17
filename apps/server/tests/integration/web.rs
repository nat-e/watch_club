use axum::http::StatusCode;
use watch_club::testing::database;

use crate::support::Client;

#[tokio::test]
async fn unknown_paths_are_not_found_rather_than_the_web_app() {
    let db = database().await;
    let mut client = Client::new(&db);
    for path in ["/api", "/api/", "/api/nothing-here"] {
        let get = client.get(path).await;
        let post = client.post_without_body(path).await;

        assert_eq!(get.status, StatusCode::NOT_FOUND, "GET {path}");
        assert_eq!(post.status, StatusCode::NOT_FOUND, "POST {path}");
    }
}

#[tokio::test]
async fn only_get_and_head_reach_the_web_app() {
    let db = database().await;
    let response = Client::new(&db).post_without_body("/index.html").await;

    assert_eq!(response.status, StatusCode::METHOD_NOT_ALLOWED);
}
