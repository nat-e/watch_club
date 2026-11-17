//! The accounts of Users: Setup, signing in and out, and User Preferences.

mod preferences;
mod user;

pub use self::{
    preferences::{Locale, change_locale},
    user::{
        CreateInstanceAdministratorError, Password, PasswordError, SESSION_LIFETIME, SessionToken,
        User, UserId, Username, UsernameError, create_instance_administrator,
        delete_expired_sessions, has_instance_administrator, session_user, sign_in, sign_out,
    },
};
