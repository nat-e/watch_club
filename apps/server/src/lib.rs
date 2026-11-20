//! The app assembled into one router, as a library that `main.rs`, the tests and `bin/` share.

use std::sync::Arc;

use axum::{Router, extract::FromRef};

// Lets the paths in `sqlx.toml` start with `::watch_club` here too, as in the binaries and tests
extern crate self as watch_club;

pub mod api_client;
mod auth;
pub mod config;
pub mod db;
pub mod domain;
mod error;
pub mod jobs;
pub mod observability;
pub mod openapi;
pub mod routes;
pub mod utils;
mod web;

/// What the request handlers share, which `router` takes. Jobs have theirs, `jobs::JobContext`.
#[derive(Clone, Debug, FromRef)]
pub struct ApiContext {
    pub db: db::Pool,
    /// The name Users see for the Instance, which `GET /api/instance` gives the apps
    pub instance_name: Arc<str>,
    pub apps_sentry: AppsSentry,
    pub metadata_providers: domain::contents::MetadataProviders,
    pub encryption_key: utils::encryption::EncryptionKey,
    /// The connections that the calls to Sources' apps share
    pub http_client: api_client::HttpClient,
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
pub fn router(context: ApiContext) -> Router {
    let (router, _) = routes::routes().split_for_parts();
    router.with_state(context)
}
