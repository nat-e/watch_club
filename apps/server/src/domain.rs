//! The domain, which the API in `routes` uses.
//!
//! Its functions fail with an `anyhow::Error` when callers can only report the failure, such as the
//! database being down. A function whose callers handle some failures, such as a missing Source,
//! has its own error type, whose `Internal` variant holds the others.

pub mod accounts;
pub mod contents;
pub mod sources;
