//! The server's tests, in one crate so they compile and link once: the domain through its public
//! functions, the API through requests to the app's router, and the settings through the server's
//! binary.

#![expect(clippy::unwrap_used, reason = "a failed unwrap fails the test")]

mod config;
mod domain {
    mod accounts {
        mod preferences;
        mod user;
    }
}
mod jobs;
mod routes {
    mod auth {
        mod login;
        mod login_token;
        mod logout;
    }
    mod health {
        mod get;
    }
    mod instance {
        mod create_administrator;
        mod get;
    }
    mod me {
        mod get;
        mod update_preferences;
    }
}
mod support;
mod web;
