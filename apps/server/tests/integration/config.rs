//! Tests the settings by starting the server's binary with chosen environment variables, as tests
//! can't change their own process's variables without `unsafe`.

use crate::support::{UNREACHABLE_DATABASE_URL, server_startup_error};

#[test]
fn fails_when_a_variable_is_not_set() {
    let errors = server_startup_error(&[("PORT", "4000")]);

    assert!(errors.contains("DATABASE_URL isn't set"), "{errors}");
}

#[test]
fn counts_an_empty_variable_as_not_set() {
    let errors = server_startup_error(&[("DATABASE_URL", ""), ("PORT", "4000")]);

    assert!(errors.contains("DATABASE_URL isn't set"), "{errors}");
}

#[test]
fn fails_when_the_port_is_not_a_number() {
    let errors =
        server_startup_error(&[("DATABASE_URL", UNREACHABLE_DATABASE_URL), ("PORT", "4o00")]);

    assert!(errors.contains("PORT isn't a port number"), "{errors}");
}

/// The settings the server needs, with a database URL it fails to connect to at once, once it gets
/// past the other settings
const REQUIRED: [(&str, &str); 4] = [
    ("DATABASE_URL", "not a database URL"),
    ("PORT", "4000"),
    ("TMDB_API_TOKEN", "tmdb-token"),
    ("HARDCOVER_API_TOKEN", "hardcover-token"),
];

/// Returns what the server printed when it failed to start with the required settings and these.
fn startup_error_with(vars: &[(&'static str, &'static str)]) -> String {
    server_startup_error(&[&REQUIRED[..], vars].concat())
}

#[test]
fn fails_without_a_tmdb_token() {
    let errors =
        server_startup_error(&[("DATABASE_URL", UNREACHABLE_DATABASE_URL), ("PORT", "4000")]);

    assert!(errors.contains("TMDB_API_TOKEN isn't set"), "{errors}");
}

#[test]
fn fails_without_a_hardcover_token() {
    let errors = server_startup_error(&[
        ("DATABASE_URL", UNREACHABLE_DATABASE_URL),
        ("PORT", "4000"),
        ("TMDB_API_TOKEN", "tmdb-token"),
    ]);

    assert!(errors.contains("HARDCOVER_API_TOKEN isn't set"), "{errors}");
}

#[test]
fn fails_when_the_encryption_key_is_not_32_bytes_in_base64() {
    let errors = startup_error_with(&[("ENCRYPTION_KEY", "c2hvcnQ=")]);

    assert!(errors.contains("ENCRYPTION_KEY isn't a key"), "{errors}");
    assert!(errors.contains("openssl rand -base64 32"), "{errors}");
}

#[test]
fn starts_without_the_optional_settings() {
    let errors = startup_error_with(&[
        ("SENTRY_DSN", ""),
        ("OTEL_TRACES_EXPORTER", ""),
        ("ENCRYPTION_KEY", ""),
    ]);

    assert!(
        errors.contains("failed to connect to the database"),
        "{errors}"
    );
}

#[test]
fn fails_when_the_instance_name_is_too_long() {
    let errors = startup_error_with(&[("INSTANCE_NAME", "The Very Long Name of Our Watch Club")]);

    assert!(
        errors.contains("INSTANCE_NAME can't be longer than 30 characters"),
        "{errors}"
    );
}

#[test]
fn fails_when_the_log_level_is_invalid() {
    let errors = startup_error_with(&[("LOG_LEVEL", "watch_club=loud")]);

    assert!(errors.contains("LOG_LEVEL isn't a log level"), "{errors}");
}

#[test]
fn fails_when_the_log_format_is_unknown() {
    let errors = startup_error_with(&[("LOG_FORMAT", "logfmt")]);

    assert!(
        errors.contains("LOG_FORMAT must be text or json, not logfmt"),
        "{errors}"
    );
}

#[test]
fn fails_when_a_signal_has_another_exporter_than_otlp() {
    let errors = startup_error_with(&[("OTEL_TRACES_EXPORTER", "jaeger")]);

    assert!(
        errors.contains("OTEL_TRACES_EXPORTER must be otlp or none, not jaeger"),
        "{errors}"
    );
}

#[test]
fn ignores_the_exporters_when_opentelemetry_is_disabled() {
    let errors = startup_error_with(&[
        ("OTEL_SDK_DISABLED", "true"),
        ("OTEL_TRACES_EXPORTER", "jaeger"),
    ]);

    assert!(
        errors.contains("failed to connect to the database"),
        "{errors}"
    );
}

#[test]
fn fails_when_the_mobile_apps_sentry_dsn_is_invalid() {
    let errors = startup_error_with(&[("SENTRY_MOBILE_DSN", "https://sentry.example.com")]);

    assert!(
        errors.contains("SENTRY_MOBILE_DSN isn't a Sentry DSN"),
        "{errors}"
    );
}

#[test]
fn fails_when_a_sentry_dsn_is_invalid() {
    let errors = startup_error_with(&[("SENTRY_WEB_DSN", "https://sentry.example.com")]);

    assert!(
        errors.contains("SENTRY_WEB_DSN isn't a Sentry DSN"),
        "{errors}"
    );
}
