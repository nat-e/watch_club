//! The domain, which the API in `routes` uses.

pub mod accounts;

/// A failure that callers don't handle, such as the database being down: they report it.
#[derive(Debug, thiserror::Error)]
#[error(transparent)]
pub struct InternalError(#[from] anyhow::Error);
