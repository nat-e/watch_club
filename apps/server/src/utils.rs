//! Helpers that know nothing about WatchClub's domain, grouped by what they work on. Add a helper
//! to the submodule of its topic, or start a submodule when no topic fits, rather than a file of
//! miscellaneous helpers.

pub mod encryption;
pub mod filesystem;
pub(crate) mod time;
pub mod url;
