//! The app assembled into one router, as a library that `main.rs`, the tests and `bin/` share.

use std::sync::Arc;

use axum::{Router, extract::FromRef, middleware, routing::get};
use sqlx::PgPool;

// Lets the paths in `sqlx.toml` start with `::watch_club` here too, as in the binaries and tests
extern crate self as watch_club;

mod auth;
pub mod domain;
mod error;
pub mod observability;
pub mod openapi;
pub mod routes;
mod web;

/// What the request handlers share.
#[derive(Clone, FromRef)]
struct AppState {
    db: PgPool,
    /// The Sentry DSN the web app reports its errors to, if the host set one
    web_sentry_dsn: Option<Arc<str>>,
}

/// Connects to the app's database, and runs its pending migrations.
pub async fn connect_database(url: &str) -> Result<PgPool, sqlx::Error> {
    let db = PgPool::connect(url).await?;
    sqlx::migrate!().run(&db).await?;
    Ok(db)
}

/// Builds the app's router: the API under `/api`, and the web app on every other path. The web app
/// reports its errors to `web_sentry_dsn`, if any.
pub fn router(db: PgPool, web_sentry_dsn: Option<String>) -> Router {
    let app = Router::new()
        .merge(routes::routes())
        .fallback_service(get(web::serve))
        .layer(middleware::from_fn(error::log_internal_errors));
    observability::instrument(app)
        .merge(routes::health_check())
        .with_state(AppState {
            db,
            web_sentry_dsn: web_sentry_dsn.map(Arc::from),
        })
}
