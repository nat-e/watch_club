//! The app assembled into one router, as a library that `main.rs`, the tests and `bin/` share.

use std::sync::Arc;

use axum::{Router, extract::FromRef};

// Lets the paths in `sqlx.toml` start with `::watch_club` here too, as in the binaries and tests
extern crate self as watch_club;

mod auth;
pub mod config;
pub mod db;
pub mod domain;
mod error;
pub mod integrations;
pub mod jobs;
pub mod observability;
pub mod openapi;
pub mod routes;
mod web;

/// The state the request handlers share, which `router` takes.
#[derive(Clone, Debug, FromRef)]
pub struct AppState {
    pub db: db::Pool,
    pub apps_sentry: AppsSentry,
    pub tmdb: integrations::tmdb::Client,
}

/// The Sentry settings the apps report their errors with, which `GET /api/instance` gives them.
#[derive(Clone, Debug)]
pub struct AppsSentry {
    /// The DSN of the web app's Sentry project, if the host set one
    pub web_dsn: Option<Arc<str>>,
    /// The DSN of the mobile apps' Sentry project, if the host set one
    pub mobile_dsn: Option<Arc<str>>,
    /// The environment their reports name, as the server's do
    pub environment: Arc<str>,
}

/// Builds the app's router, with the routes in `routes`.
pub fn router(state: AppState) -> Router {
    let (router, _) = routes::routes().split_for_parts();
    router.with_state(state)
}
