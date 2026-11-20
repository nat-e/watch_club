//! The folders on the server that someone enters, through `utils::filesystem::AbsoluteFolder`.

use watch_club::utils::filesystem::{AbsoluteFolder, FolderError};

/// A folder that exists wherever the tests run
const FOLDER: &str = env!("CARGO_MANIFEST_DIR");

#[tokio::test]
async fn reads_the_path_without_the_spaces_around_it_or_a_trailing_slash() {
    let folder = AbsoluteFolder::parse(&format!(" {FOLDER}/ "))
        .await
        .unwrap();

    assert_eq!(folder.as_str(), FOLDER);
}

#[tokio::test]
async fn refuses_paths_that_dont_start_from_the_root() {
    for path in ["", "  ", "movies", "./movies"] {
        assert_eq!(
            AbsoluteFolder::parse(path).await,
            Err(FolderError::NotAbsolute),
            "{path:?}"
        );
    }
}

#[tokio::test]
async fn refuses_the_root() {
    assert_eq!(
        AbsoluteFolder::parse("/").await,
        Err(FolderError::NotAbsolute)
    );
}

#[tokio::test]
async fn refuses_paths_where_there_is_no_folder() {
    for path in [
        "/no/such/folder",
        concat!(env!("CARGO_MANIFEST_DIR"), "/Cargo.toml"),
    ] {
        assert_eq!(
            AbsoluteFolder::parse(path).await,
            Err(FolderError::NotFound),
            "{path}"
        );
    }
}
