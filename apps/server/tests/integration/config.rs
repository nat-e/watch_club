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
const REQUIRED: [(&str, &str); 2] = [("DATABASE_URL", "not a database URL"), ("PORT", "4000")];

/// Returns what the server printed when it failed to start with the required settings and these.
fn startup_error_with(vars: &[(&'static str, &'static str)]) -> String {
    server_startup_error(&[&REQUIRED[..], vars].concat())
}

#[test]
fn starts_without_the_optional_settings() {
    let errors = startup_error_with(&[("SENTRY_DSN", ""), ("OTEL_TRACES_EXPORTER", "")]);

    assert!(
        errors.contains("failed to connect to the database"),
        "{errors}"
    );
}

#[test]
fn fails_when_the_log_filter_is_invalid() {
    let errors = startup_error_with(&[("RUST_LOG", "watch_club=loud")]);

    assert!(errors.contains("RUST_LOG isn't a log filter"), "{errors}");
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
fn fails_when_a_sentry_dsn_is_invalid() {
    let errors = startup_error_with(&[("SENTRY_WEB_DSN", "https://sentry.example.com")]);

    assert!(
        errors.contains("SENTRY_WEB_DSN isn't a Sentry DSN"),
        "{errors}"
    );
}
