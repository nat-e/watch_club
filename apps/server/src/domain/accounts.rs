//! The accounts of Users: Setup, which creates the Instance Administrator, Invitations, the list of
//! Users and their passwords, the sessions that keep them signed in, and User Preferences.
//!
//! Callers reach each part through its module, such as `users::delete`.

pub mod instance_administrator;
pub mod invitations;
pub mod preferences;
pub mod sessions;
mod token;
pub mod users;
