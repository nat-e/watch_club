//! The app assembled into one router, as a library that `main.rs`, the tests and `bin/` share.

use axum::{Router, middleware, routing::get};
use sqlx::{PgPool, postgres::PgPoolOptions};
use tower_http::trace::{DefaultMakeSpan, TraceLayer};
use tracing::Level;

// Lets the paths in `sqlx.toml` start with `::watch_club` here too, as in the binaries and tests
extern crate self as watch_club;

mod auth;
pub mod domain;
mod error;
pub mod jobs;
pub mod openapi;
pub mod routes;
mod web;

/// Connects to the app's database, and runs its pending migrations.
pub async fn connect_database(url: &str) -> Result<PgPool, sqlx::Error> {
    let db = PgPoolOptions::new()
        // Shared by the requests and the jobs, which hold one only while a query runs
        .max_connections(10)
        .connect(url)
        .await?;
    sqlx::migrate!().run(&db).await?;
    Ok(db)
}

/// Builds the app's router: the API under `/api`, and the web app on every other path.
pub fn router(db: PgPool) -> Router {
    Router::new()
        .merge(routes::routes())
        .fallback_service(get(web::serve))
        .layer(middleware::from_fn(error::log_internal_errors))
        .layer(
            TraceLayer::new_for_http()
                // Shows the method and path on every log line written during a request
                .make_span_with(DefaultMakeSpan::new().level(Level::INFO))
                // `log_internal_errors` logs the 500s, with their cause
                .on_failure(()),
        )
        .with_state(db)
}
