//! The accounts of Users: Setup, Invitations, signing in and out, passwords, the list of Users, and
//! User Preferences.

mod invitations;
mod passwords;
mod preferences;
mod token;
mod user;

pub use self::{
    invitations::{
        DeleteInvitationError, Invitation, InvitationId, RedeemInvitationError,
        UpdateInvitationError, create_invitation, delete_invitation, is_redeemable,
        list_redeemable_invitations, redeem_invitation, update_invitation,
    },
    passwords::{
        ChangePasswordError, CreatePasswordResetLinkError, ResetPasswordError, change_password,
        create_password_reset_link, password_reset_username, reset_password,
    },
    preferences::{AudioLanguage, Locale, TrackLanguage, UserPreferences, save_preferences},
    user::{
        CreateInstanceAdministratorError, CurrentUser, DeleteUserError, Password, PasswordError,
        SESSION_LIFETIME, SessionToken, User, UserId, Username, UsernameError,
        create_instance_administrator, delete_expired_sessions, delete_user,
        has_instance_administrator, list_users, session_user, sign_in, sign_out,
    },
};
