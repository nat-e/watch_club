//! The server's tests, in one crate so they compile and link once: the domain through its public
//! functions, the API through requests to the app's router, and the settings through the server's
//! binary.

#![expect(clippy::unwrap_used, reason = "a failed unwrap fails the test")]

mod config;
mod domain {
    mod accounts {
        mod invitations;
        mod passwords;
        mod preferences;
        mod user;
    }
    mod contents;
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
    mod invitations {
        mod check;
        mod create;
        mod delete;
        mod list;
        mod redeem;
        mod update;
    }
    mod contents {
        mod get;
        mod list_media;
    }
    mod me {
        mod change_password;
        mod get;
        mod update_preferences;
    }
    mod password_reset {
        mod check;
        mod reset;
    }
    mod search {
        mod get;
    }
    mod users {
        mod create_password_reset_link;
        mod delete;
        mod list;
    }
}
mod support;
mod web;
