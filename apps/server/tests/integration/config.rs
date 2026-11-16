//! Tests the settings by starting the server's binary with chosen environment variables, as tests
//! can't change their own process's variables without `unsafe`.

use std::process::Command;

/// A database URL nothing listens on, so a server that gets past its settings fails fast
const UNREACHABLE_DATABASE_URL: &str = "postgres://localhost:1/watch_club";

/// Runs the server with only these environment variables, and returns what it printed when it
/// failed to start.
fn start_server(vars: &[(&str, &str)]) -> String {
    let output = Command::new(env!("CARGO_BIN_EXE_watch_club"))
        .env_clear()
        .envs(vars.iter().copied())
        .output()
        .unwrap();
    assert!(!output.status.success());
    String::from_utf8(output.stderr).unwrap()
}

#[test]
fn fails_when_a_variable_is_not_set() {
    let errors = start_server(&[("PORT", "4000")]);

    assert!(errors.contains("DATABASE_URL isn't set"), "{errors}");
}

#[test]
fn counts_an_empty_variable_as_not_set() {
    let errors = start_server(&[("DATABASE_URL", ""), ("PORT", "4000")]);

    assert!(errors.contains("DATABASE_URL isn't set"), "{errors}");
}

#[test]
fn fails_when_the_port_is_not_a_number() {
    let errors = start_server(&[("DATABASE_URL", UNREACHABLE_DATABASE_URL), ("PORT", "4o00")]);

    assert!(errors.contains("PORT isn't a port number"), "{errors}");
}
