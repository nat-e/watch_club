//! The server's settings, which it reads from environment variables when it starts.
//! `observability` reads the OpenTelemetry and Sentry ones, which follow their standards.

use std::env;

use anyhow::Context;
use secrecy::SecretString;

/// The server's settings.
#[derive(Debug)]
pub struct Config {
    /// The URL of the Postgres database, from `DATABASE_URL`. It holds the database's password
    pub database_url: SecretString,
    /// The port the server listens on, from `PORT`
    pub port: u16,
}

impl Config {
    /// Reads the settings from the environment variables, or fails on the first that's missing or
    /// invalid.
    pub fn from_env() -> anyhow::Result<Self> {
        Ok(Self {
            database_url: database_url()?,
            port: required_var("PORT")?
                .parse()
                .context("PORT isn't a port number")?,
        })
    }
}

/// Reads the URL of the Postgres database from `DATABASE_URL`, for tools that only need the
/// database, which shouldn't need the server's other settings.
pub fn database_url() -> anyhow::Result<SecretString> {
    required_var("DATABASE_URL").map(SecretString::from)
}

/// Returns the value of the environment variable `name`. An empty value counts as unset.
fn required_var(name: &str) -> anyhow::Result<String> {
    env::var(name)
        .ok()
        .filter(|value| !value.is_empty())
        .with_context(|| format!("{name} isn't set"))
}
