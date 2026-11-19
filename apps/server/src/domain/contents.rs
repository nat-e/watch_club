//! Content: the Movies, TV Shows, Sports Events and Books that Users search for, from the Metadata
//! Providers.

mod image;
mod metadata_providers;

use std::num::NonZeroU32;

use jiff::civil::Date;
use serde::{Deserialize, Serialize};
use utoipa::{
    PartialSchema, ToSchema,
    openapi::{RefOr, Schema},
};

pub use self::{
    image::{Image, ImageSource},
    metadata_providers::{
        Hardcover, HardcoverId, MetadataProviders, Sportarr, SportarrId, Tmdb, TmdbId,
    },
};
use super::{InternalError, accounts::Locale};

/// The type of a Content.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum ContentType {
    Movie,
    TvShow,
    SportsEvent,
    Book,
}

/// The Content Types a search looks for, each at the Metadata Provider of its types.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum SearchScope {
    /// Movies and TV Shows, at TMDB
    MoviesAndTvShows,
    /// Sports Events, at sportarr.net
    SportsEvents,
    /// Books, at Hardcover
    Books,
}

/// The identity of a Content: its type, and its External ID at the Metadata Provider of its type.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(into = "ContentIdJson")]
pub enum ContentId {
    Movie(TmdbId),
    TvShow(TmdbId),
    SportsEvent(SportarrId),
    Book(HardcoverId),
}

impl ContentId {
    /// Returns the ID of the Content of this type with this External ID, as the API and URLs carry
    /// it, or None when the text can't be one.
    pub fn parse(content_type: ContentType, external_id: &str) -> Option<Self> {
        match content_type {
            ContentType::Movie => external_id.parse().ok().map(Self::Movie),
            ContentType::TvShow => external_id.parse().ok().map(Self::TvShow),
            ContentType::SportsEvent => Some(Self::SportsEvent(SportarrId::new(external_id))),
            ContentType::Book => external_id.parse().ok().map(Self::Book),
        }
    }

    pub const fn content_type(&self) -> ContentType {
        match self {
            Self::Movie(_) => ContentType::Movie,
            Self::TvShow(_) => ContentType::TvShow,
            Self::SportsEvent(_) => ContentType::SportsEvent,
            Self::Book(_) => ContentType::Book,
        }
    }

    /// Returns its External ID as text, as the API and URLs carry it.
    pub fn external_id(&self) -> String {
        match self {
            Self::Movie(id) | Self::TvShow(id) => id.to_string(),
            Self::SportsEvent(id) => id.to_string(),
            Self::Book(id) => id.to_string(),
        }
    }
}

/// The identity of a Content as the API sends it: its type, and its External ID at the Metadata
/// Provider of its type, as text whatever the Metadata Provider.
#[derive(Serialize, ToSchema)]
struct ContentIdJson {
    content_type: ContentType,
    /// The Content's ID at the Metadata Provider of its type, such as its TMDB ID, or `ev-028133` at
    /// sportarr.net
    external_id: String,
}

impl From<ContentId> for ContentIdJson {
    fn from(id: ContentId) -> Self {
        Self {
            content_type: id.content_type(),
            external_id: id.external_id(),
        }
    }
}

impl PartialSchema for ContentId {
    fn schema() -> RefOr<Schema> {
        ContentIdJson::schema()
    }
}

impl ToSchema for ContentId {
    fn schemas(schemas: &mut Vec<(String, RefOr<Schema>)>) {
        ContentIdJson::schemas(schemas);
    }
}

/// A Content, with its title in the User's language when its Metadata Provider has it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct Content {
    #[serde(flatten)]
    pub id: ContentId,
    pub title: String,
}

/// A Content that matches a search, with its texts in the User's language when its Metadata
/// Provider has them.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct SearchResult {
    #[serde(flatten)]
    pub id: ContentId,
    pub title: String,
    /// The day it came out, first aired or takes place, when its Metadata Provider knows it. A Book
    /// whose day Hardcover doesn't know comes out on January 1st of its year
    #[schema(value_type = Option<String>, format = Date, required = true)]
    pub date: Option<Date>,
    #[schema(required = true)]
    pub overview: Option<String>,
    #[schema(required = true)]
    pub poster: Option<Image>,
    /// The people credited for making it, most important first, such as a Book's authors. None for
    /// Movies, TV Shows and Sports Events for now
    pub creators: Vec<String>,
    /// The league or competition of a Sports Event, such as UFC or Formula 1, when sportarr.net
    /// knows it. Null for other Content
    #[schema(required = true)]
    pub league: Option<String>,
}

/// A page of a search's results.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, ToSchema)]
pub struct SearchResults {
    /// The results, most relevant first, or the latest first for Sports Events. Only the last page
    /// can have none, unless TMDB's pages in between have only people and videos
    pub results: Vec<SearchResult>,
    /// The number of the next page, or null on the last one
    #[schema(value_type = Option<u32>, required = true, minimum = 2)]
    pub next_page: Option<NonZeroU32>,
}

/// The failures of `look_up`.
#[derive(Debug, thiserror::Error)]
pub enum LookUpError {
    #[error("no such Content")]
    NotFound,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Returns a page of the Content of the scope that matches the query, most relevant first, or the
/// latest first for Sports Events, with their texts in the Locale's language when their Metadata
/// Provider has them. A blank query matches nothing.
#[tracing::instrument(skip_all, fields(search.scope = ?scope, search.page = page))]
pub async fn search(
    metadata_providers: &MetadataProviders,
    query: &str,
    scope: SearchScope,
    page: NonZeroU32,
    locale: Locale,
) -> Result<SearchResults, InternalError> {
    let query = query.trim();
    if query.is_empty() {
        return Ok(SearchResults::default());
    }

    match scope {
        SearchScope::MoviesAndTvShows => metadata_providers.tmdb.search(query, page, locale).await,
        SearchScope::SportsEvents => metadata_providers.sportarr.search(query, page).await,
        SearchScope::Books => metadata_providers.hardcover.search(query, page).await,
    }
}

/// Returns the Content, with its title in the Locale's language when its Metadata Provider has it.
#[tracing::instrument(
    skip_all,
    fields(content.type = ?id.content_type(), content.external_id = %id.external_id()),
)]
pub async fn look_up(
    metadata_providers: &MetadataProviders,
    id: ContentId,
    locale: Locale,
) -> Result<Content, LookUpError> {
    match id {
        ContentId::Movie(id) => metadata_providers.tmdb.look_up_movie(id, locale).await,
        ContentId::TvShow(id) => metadata_providers.tmdb.look_up_tv_show(id, locale).await,
        ContentId::SportsEvent(id) => metadata_providers.sportarr.look_up_sports_event(id).await,
        ContentId::Book(id) => metadata_providers.hardcover.look_up_book(id).await,
    }
}
