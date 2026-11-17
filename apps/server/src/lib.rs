//! The app assembled into one router, as a library that `main.rs`, the tests and `bin/` share.

use std::sync::Arc;

use axum::{Router, extract::FromRef};
use sqlx::PgPool;

// Lets the paths in `sqlx.toml` start with `::watch_club` here too, as in the binaries and tests
extern crate self as watch_club;

mod auth;
pub mod config;
pub mod db;
pub mod domain;
mod error;
pub mod jobs;
pub mod observability;
pub mod openapi;
pub mod routes;
mod web;

/// The state the request handlers share, which `router` takes.
#[derive(Clone, Debug, FromRef)]
pub struct AppState {
    pub db: PgPool,
    /// The Sentry DSN the web app reports its errors to, if the host set one
    pub web_sentry_dsn: Option<Arc<str>>,
}

/// Builds the app's router, with the routes in `routes`.
pub fn router(state: AppState) -> Router {
    let (router, _) = routes::routes().split_for_parts();
    router.with_state(state)
}
