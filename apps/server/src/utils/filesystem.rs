//! Folders and paths on the server, as someone enters them.

use std::{
    fmt::{self, Display, Formatter},
    path::Path,
};

use serde::Serialize;
use utoipa::ToSchema;

/// The reasons WatchClub can't read a folder.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
pub enum FolderError {
    /// Such as `movies` rather than `/media/movies`, or the root, which is the whole server rather
    /// than one of its folders
    #[error("the path doesn't start from the root")]
    NotAbsolute,
    /// Nothing is there, or a file is
    #[error("no folder is at the path on the server")]
    NotFound,
}

/// The path of a folder on the server, from the root: trimmed, without a trailing `/`, and not the
/// root, which is the whole server rather than one of its folders. The folder was there when
/// `parse` looked, but it may have been moved since.
// Read from the database unchecked: only `parse` makes the paths it stores
#[derive(Clone, Debug, PartialEq, Eq, sqlx::Type)]
#[sqlx(transparent)]
pub struct AbsoluteFolder(String);

impl AbsoluteFolder {
    /// Trims the path that someone entered and drops its trailing `/`, then checks that it starts
    /// from the root and that a folder is there on the server.
    pub async fn parse(path: &str) -> Result<Self, FolderError> {
        let path = path.trim().trim_end_matches('/');
        // Also refuses the root, which `/` trimmed to nothing
        if path.is_empty() || !Path::new(path).is_absolute() {
            return Err(FolderError::NotAbsolute);
        }

        let is_folder = tokio::fs::metadata(path)
            .await
            .is_ok_and(|metadata| metadata.is_dir());
        if !is_folder {
            return Err(FolderError::NotFound);
        }

        Ok(Self(path.to_owned()))
    }

    /// Returns the path, such as `/media/movies`.
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl Display for AbsoluteFolder {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}
