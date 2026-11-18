//! The accounts of Users: Setup, signing in and out, and User Preferences.

mod preferences;
mod user;

pub use self::{
    preferences::{AudioLanguage, Locale, TrackLanguage, UserPreferences, save_preferences},
    user::{
        CreateInstanceAdministratorError, CurrentUser, Password, PasswordError, SESSION_LIFETIME,
        SessionToken, UserId, Username, UsernameError, create_instance_administrator,
        delete_expired_sessions, has_instance_administrator, session_user, sign_in, sign_out,
    },
};
