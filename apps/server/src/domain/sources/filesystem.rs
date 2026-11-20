//! Filesystem Sources: a folder on the server, whose files and subfolders' files all have one Media
//! Type.

use crate::{
    domain::contents::MediaType,
    utils::filesystem::{AbsoluteFolder, FolderError},
};

/// The Source Configuration of a Filesystem Source.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FilesystemConfiguration {
    /// The Media Type of every file in the folder, which the Instance Administrator chose
    pub media_type: MediaType,
    /// The folder on the server
    pub path: AbsoluteFolder,
}

/// The Source Configuration the Instance Administrator enters for a Filesystem Source.
#[derive(Debug)]
pub struct FilesystemConfigurationInput {
    pub media_type: MediaType,
    pub path: String,
}

impl FilesystemConfiguration {
    /// Returns the configuration to save, once `AbsoluteFolder::parse` found the folder on the
    /// server.
    pub(super) async fn parse(
        configuration: FilesystemConfigurationInput,
    ) -> Result<Self, FolderError> {
        let path = AbsoluteFolder::parse(&configuration.path).await?;

        Ok(Self {
            media_type: configuration.media_type,
            path,
        })
    }
}
