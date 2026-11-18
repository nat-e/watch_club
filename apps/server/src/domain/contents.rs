//! Content: the Movies and TV Shows that Users search for, from TMDB.

use std::num::NonZeroU32;

use jiff::civil::Date;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use super::{InternalError, accounts::Locale};
use crate::integrations::tmdb::{self, MultiSearchResult};

/// The last page of results TMDB serves
const LAST_PAGE: u32 = 500;

/// The type of a Content.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum ContentType {
    Movie,
    TvShow,
}

/// What identifies a Content: its type and its TMDB ID. A Movie and a TV Show can have the same
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
    /// The results, most relevant first. A page can have none while later pages have some
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

impl From<tmdb::Error> for LookUpError {
    fn from(error: tmdb::Error) -> Self {
        match error {
            tmdb::Error::NotFound => Self::NotFound,
            tmdb::Error::Internal(error) => Self::Internal(error),
        }
    }
}

/// Returns a page of the Movies and TV Shows whose title matches the query, from TMDB, most
/// relevant first, with their texts in the Locale's language. A blank query matches nothing.
#[tracing::instrument(skip_all, fields(search.page = page))]
pub async fn search(
    tmdb: &tmdb::Client,
    query: &str,
    page: NonZeroU32,
    locale: Locale,
) -> Result<SearchResults, InternalError> {
    let query = query.trim();
    if query.is_empty() {
        return Ok(SearchResults::default());
    }
    let found = tmdb.search_multi(query, page, locale).await?;
    let results = found
        .results
        .into_iter()
        .filter_map(|result| match result {
            MultiSearchResult::Movie(movie) => Some(SearchResult {
                id: ContentId {
                    content_type: ContentType::Movie,
                    tmdb_id: movie.id,
                },
                title: movie.title,
                year: movie.release_date.map(Date::year),
                overview: movie.overview,
                poster_path: movie.poster_path,
            }),
            MultiSearchResult::TvShow(tv_show) => Some(SearchResult {
                id: ContentId {
                    content_type: ContentType::TvShow,
                    tmdb_id: tv_show.id,
                },
                title: tv_show.name,
                year: tv_show.first_air_date.map(Date::year),
                overview: tv_show.overview,
                poster_path: tv_show.poster_path,
            }),
            // People aren't Content
            MultiSearchResult::Person(_) => None,
        })
        .collect();
    let next_page = page
        .checked_add(1)
        .filter(|next| next.get() <= found.total_pages.min(LAST_PAGE));
    Ok(SearchResults { results, next_page })
}

/// Returns the Content, with its title in the Locale's language, from TMDB.
#[tracing::instrument(skip_all, fields(content.type = ?id.content_type, content.tmdb_id = id.tmdb_id))]
pub async fn look_up(
    tmdb: &tmdb::Client,
    id: ContentId,
    locale: Locale,
) -> Result<Content, LookUpError> {
    let title = match id.content_type {
        ContentType::Movie => tmdb.movie_details(id.tmdb_id, locale).await?.title,
        ContentType::TvShow => tmdb.tv_show_details(id.tmdb_id, locale).await?.name,
    };
    Ok(Content { id, title })
}
