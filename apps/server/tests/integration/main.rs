//! The server's tests, in one crate so they compile and link once: the domain and the helpers
//! through their public functions, the API through requests to the app's router, and the settings
//! through the server's binary.

#![expect(clippy::unwrap_used, reason = "a failed unwrap fails the test")]

mod config;
mod domain {
    mod accounts {
        mod invitations;
        mod preferences;
        mod user;
    }
    mod contents;
    mod sources;
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
        mod get;
        mod update_preferences;
    }
    mod search {
        mod get;
    }
    mod sources {
        mod check;
        mod create;
        mod delete;
        mod list;
        mod update;
    }
    mod users {
        mod delete;
        mod list;
    }
}
mod support;
mod utils {
    mod filesystem;
    mod url;
}
mod web;
