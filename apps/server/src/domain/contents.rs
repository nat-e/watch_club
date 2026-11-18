//! Content: the Movies and TV Shows that Users search for, from the Metadata Providers.

mod metadata_providers;

use std::num::NonZeroU32;

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

pub use self::metadata_providers::{MetadataProviders, Tmdb};
use super::{InternalError, accounts::Locale};

/// The type of a Content.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum ContentType {
    Movie,
    TvShow,
}

/// The identity of a Content: its type and its TMDB ID. A Movie and a TV Show can have the same
/// TMDB ID.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct ContentId {
    pub content_type: ContentType,
    pub tmdb_id: u32,
}

/// A Content, with its title in the User's language.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct Content {
    #[serde(flatten)]
    pub id: ContentId,
    pub title: String,
}

/// A Movie or a TV Show that matches a search, with its texts in the User's language.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct SearchResult {
    #[serde(flatten)]
    pub id: ContentId,
    pub title: String,
    /// The year of its release, or of its first episode, when TMDB knows it
    #[schema(required = true)]
    pub year: Option<i16>,
    #[schema(required = true)]
    pub overview: Option<String>,
    /// The path of its poster on TMDB's image server
    #[schema(required = true)]
    pub poster_path: Option<String>,
}

/// A page of a search's results.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, ToSchema)]
pub struct SearchResults {
    /// The results, most relevant first. Only the last page can have none, unless TMDB's pages
    /// in between have only people
    pub results: Vec<SearchResult>,
    /// The number of the next page, or null on the last one
    #[schema(value_type = Option<u32>, required = true, minimum = 2)]
    pub next_page: Option<NonZeroU32>,
}

/// The failures of `look_up`.
#[derive(Debug, thiserror::Error)]
pub enum LookUpError {
    #[error("TMDB has no such Content")]
    NotFound,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Returns a page of the Movies and TV Shows whose title matches the query, most relevant first,
/// with their texts in the Locale's language. A blank query matches nothing.
#[tracing::instrument(skip_all, fields(search.page = page))]
pub async fn search(
    providers: &MetadataProviders,
    query: &str,
    page: NonZeroU32,
    locale: Locale,
) -> Result<SearchResults, InternalError> {
    let query = query.trim();
    if query.is_empty() {
        return Ok(SearchResults::default());
    }
    providers.tmdb.search(query, page, locale).await
}

/// Returns the Content, with its title in the Locale's language.
#[tracing::instrument(skip_all, fields(content.type = ?id.content_type, content.tmdb_id = id.tmdb_id))]
pub async fn look_up(
    providers: &MetadataProviders,
    id: ContentId,
    locale: Locale,
) -> Result<Content, LookUpError> {
    match id.content_type {
        ContentType::Movie => providers.tmdb.look_up_movie(id.tmdb_id, locale).await,
        ContentType::TvShow => providers.tmdb.look_up_tv_show(id.tmdb_id, locale).await,
    }
}
