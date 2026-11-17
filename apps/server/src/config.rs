//! The server's settings, which it reads from environment variables when it starts. The
//! OpenTelemetry and Sentry SDKs read the rest of their standard variables themselves, such as
//! `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_RESOURCE_ATTRIBUTES` and `SENTRY_ENVIRONMENT`.

use std::env;

use anyhow::{Context, bail};
use secrecy::SecretString;
use sentry::types::Dsn;
use tracing_subscriber::EnvFilter;

/// The server's settings.
#[derive(Debug)]
pub struct Config {
    /// The URL of the Postgres database, from `DATABASE_URL`. It holds the database's password
    pub database_url: SecretString,
    /// The port the server listens on, from `PORT`
    pub port: u16,
    /// The settings of the server's logs, telemetry and error reports
    pub observability: ObservabilityConfig,
}

/// The settings of the server's logs, of its OpenTelemetry export, and of the Sentry reports.
#[derive(Debug)]
pub struct ObservabilityConfig {
    /// The logs the server writes, from `RUST_LOG`: `info` by default
    pub log_filter: EnvFilter,
    /// The format of the console's logs, from `LOG_FORMAT`: text by default
    pub log_format: LogFormat,
    /// The OpenTelemetry signals the server exports
    pub exports: Exports,
    /// The name the server reports its telemetry under, from `OTEL_SERVICE_NAME`: `watch_club` by
    /// default
    pub service_name: String,
    /// The Sentry project of the server's errors, from `SENTRY_DSN`
    pub sentry_dsn: Option<Dsn>,
    /// The Sentry DSN of the web app's errors, from `SENTRY_WEB_DSN`, as the host wrote it
    pub web_sentry_dsn: Option<String>,
}

/// The format of the console's logs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogFormat {
    /// Lines for people to read, from `LOG_FORMAT=text`
    Text,
    /// One JSON object per line, which log tools read without parsing rules, from `LOG_FORMAT=json`
    Json,
}

impl LogFormat {
    fn from_env() -> anyhow::Result<Self> {
        match optional_var("LOG_FORMAT").as_deref() {
            None | Some("text") => Ok(Self::Text),
            Some("json") => Ok(Self::Json),
            Some(other) => bail!("LOG_FORMAT must be text or json, not {other}"),
        }
    }
}

/// The OpenTelemetry signals the server exports: those whose `OTEL_{SIGNAL}_EXPORTER` is `otlp`,
/// unless `OTEL_SDK_DISABLED` is `true`. Unlike the standard, which defaults to `otlp`, a signal
/// stays off unless the host turns it on.
#[derive(Debug, Default, Clone, Copy)]
pub struct Exports {
    /// Whether the server exports traces
    pub traces: bool,
    /// Whether the server exports metrics
    pub metrics: bool,
    /// Whether the server exports logs
    pub logs: bool,
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
            observability: ObservabilityConfig::from_env()?,
        })
    }
}

impl ObservabilityConfig {
    fn from_env() -> anyhow::Result<Self> {
        let log_filter = EnvFilter::try_new(optional_var("RUST_LOG").as_deref().unwrap_or("info"))
            .context("RUST_LOG isn't a log filter")?;
        let web_sentry_dsn = optional_var("SENTRY_WEB_DSN");
        if let Some(dsn) = &web_sentry_dsn {
            parse_dsn("SENTRY_WEB_DSN", dsn)?;
        }
        Ok(Self {
            log_filter,
            log_format: LogFormat::from_env()?,
            exports: Exports::from_env()?,
            service_name: optional_var("OTEL_SERVICE_NAME")
                .unwrap_or_else(|| "watch_club".to_owned()),
            sentry_dsn: optional_var("SENTRY_DSN")
                .map(|dsn| parse_dsn("SENTRY_DSN", &dsn))
                .transpose()?,
            web_sentry_dsn,
        })
    }
}

impl Exports {
    fn from_env() -> anyhow::Result<Self> {
        let disabled = optional_var("OTEL_SDK_DISABLED")
            .is_some_and(|disabled| disabled.eq_ignore_ascii_case("true"));
        if disabled {
            return Ok(Self::default());
        }
        Ok(Self {
            traces: exports("TRACES")?,
            metrics: exports("METRICS")?,
            logs: exports("LOGS")?,
        })
    }
}

/// Reads the URL of the Postgres database from `DATABASE_URL`, for tools that only need the
/// database, which shouldn't need the server's other settings.
pub fn database_url() -> anyhow::Result<SecretString> {
    required_var("DATABASE_URL").map(SecretString::from)
}

/// Returns whether `OTEL_{signal}_EXPORTER` turns the signal on.
fn exports(signal: &str) -> anyhow::Result<bool> {
    let name = format!("OTEL_{signal}_EXPORTER");
    match optional_var(&name).as_deref() {
        None | Some("none") => Ok(false),
        Some("otlp") => Ok(true),
        Some(other) => bail!("{name} must be otlp or none, not {other}"),
    }
}

/// Parses the Sentry DSN that the environment variable `name` holds.
fn parse_dsn(name: &str, dsn: &str) -> anyhow::Result<Dsn> {
    dsn.parse()
        .with_context(|| format!("{name} isn't a Sentry DSN"))
}

/// Returns the value of the environment variable `name`. An empty value counts as unset.
fn required_var(name: &str) -> anyhow::Result<String> {
    optional_var(name).with_context(|| format!("{name} isn't set"))
}

/// Returns the value of the environment variable `name`, or None when it's unset or empty.
fn optional_var(name: &str) -> Option<String> {
    env::var(name).ok().filter(|value| !value.is_empty())
}
