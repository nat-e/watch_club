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
