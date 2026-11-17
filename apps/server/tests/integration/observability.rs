//! Tests the observability settings by starting the server's binary with chosen environment
//! variables. A server that gets past them fails on the database settings instead.

use crate::support::server_startup_error;

#[test]
fn fails_when_a_signal_has_another_exporter_than_otlp() {
    let errors = server_startup_error(&[("OTEL_TRACES_EXPORTER", "jaeger")]);

    assert!(
        errors.contains("OTEL_TRACES_EXPORTER must be otlp or none, not jaeger"),
        "{errors}"
    );
}

#[test]
fn ignores_the_exporters_when_the_sdk_is_disabled() {
    let errors = server_startup_error(&[
        ("OTEL_SDK_DISABLED", "true"),
        ("OTEL_TRACES_EXPORTER", "jaeger"),
    ]);

    assert!(errors.contains("DATABASE_URL isn't set"), "{errors}");
}

#[test]
fn fails_when_a_sentry_dsn_is_invalid() {
    let errors = server_startup_error(&[("SENTRY_WEB_DSN", "https://sentry.example.com")]);

    assert!(
        errors.contains("SENTRY_WEB_DSN isn't a Sentry DSN"),
        "{errors}"
    );
}

#[test]
fn counts_an_empty_sentry_dsn_as_not_set() {
    let errors = server_startup_error(&[("SENTRY_DSN", "")]);

    assert!(errors.contains("DATABASE_URL isn't set"), "{errors}");
}
