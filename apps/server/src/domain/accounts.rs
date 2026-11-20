//! The accounts of Users: Setup, Invitations, signing in and out, the list of Users, and User
//! Preferences.

mod invitations;
mod preferences;
mod user;

pub use self::{
    invitations::{
        DeleteInvitationError, Invitation, InvitationId, RedeemInvitationError,
        UpdateInvitationError, create_invitation, delete_invitation, is_redeemable,
        list_redeemable_invitations, redeem_invitation, update_invitation,
    },
    preferences::{AudioLanguage, Locale, TrackLanguage, UserPreferences, save_preferences},
    user::{
        CreateInstanceAdministratorError, CurrentUser, DeleteUserError, Password, PasswordError,
        SESSION_LIFETIME, SessionToken, User, UserId, Username, UsernameError,
        create_instance_administrator, delete_expired_sessions, delete_user,
        has_instance_administrator, list_users, session_user, sign_in, sign_out,
    },
};
