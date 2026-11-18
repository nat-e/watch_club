//! The domain, which the API in `routes` uses.

pub mod accounts;
pub mod contents;

use std::any::Any;

use anyhow::anyhow;

/// A failure that callers don't handle, such as the database being down: they report it.
#[derive(Debug, thiserror::Error)]
#[error(transparent)]
pub struct InternalError(#[from] anyhow::Error);

impl InternalError {
    /// Turns a caught panic into the failure it stands for, with the panic's message when it has
    /// one, which is a `&str` or a `String`.
    pub(crate) fn from_panic(panic: &(dyn Any + Send)) -> Self {
        let message = panic
            .downcast_ref::<&str>()
            .copied()
            .or_else(|| panic.downcast_ref::<String>().map(String::as_str))
            .unwrap_or("no message");
        Self(anyhow!("panicked: {message}"))
    }
}
