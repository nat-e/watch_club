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

/// The External ID of a Content at the Metadata Provider of its type, with the type, as TMDB numbers
/// Movies and TV Shows apart. A Metadata Provider can change it, such as when it deletes a duplicate.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(into = "ExternalContentIdJson")]
pub enum ExternalContentId {
    Movie(TmdbId),
    TvShow(TmdbId),
    SportsEvent(SportarrId),
    Book(HardcoverId),
}

impl ExternalContentId {
    /// Returns the External Content ID of a Content of this type, from its External ID as the API and
    /// URLs carry it, or None when the text can't be one.
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

/// An External Content ID as the API sends it: the Content's type, and its External ID at the
/// Metadata Provider of its type, as text whatever the Metadata Provider.
#[derive(Serialize, ToSchema)]
struct ExternalContentIdJson {
    content_type: ContentType,
    /// The Content's ID at the Metadata Provider of its type, such as its TMDB ID
    external_id: String,
}

impl From<ExternalContentId> for ExternalContentIdJson {
    fn from(external_content_id: ExternalContentId) -> Self {
        Self {
            content_type: external_content_id.content_type(),
            external_id: external_content_id.external_id(),
        }
    }
}

impl PartialSchema for ExternalContentId {
    fn schema() -> RefOr<Schema> {
        ExternalContentIdJson::schema()
    }
}

impl ToSchema for ExternalContentId {
    fn schemas(schemas: &mut Vec<(String, RefOr<Schema>)>) {
        ExternalContentIdJson::schemas(schemas);
    }
}

/// A Content, with its title in the User's language when its Metadata Provider has it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct Content {
    #[serde(flatten)]
    pub external_content_id: ExternalContentId,
    pub title: String,
}

/// A Content that matches a search, with its texts in the User's language when its Metadata
/// Provider has them.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct SearchResult {
    #[serde(flatten)]
    pub external_content_id: ExternalContentId,
    pub title: String,
    /// The day it came out, first aired or takes place, when its Metadata Provider knows it
    #[schema(value_type = Option<String>, format = Date, required = true)]
    pub date: Option<Date>,
    #[schema(required = true)]
    pub overview: Option<String>,
    #[schema(required = true)]
    pub poster: Option<Image>,
    /// The people or organizations that make it, the most important first, such as a Book's authors
    /// or a Sports Event's league, when its Metadata Provider says
    pub creators: Vec<String>,
}

/// A page of a search's results.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, ToSchema)]
pub struct SearchResults {
    /// The results, in their Metadata Provider's order. Pages before the last can have none
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

/// Returns a page of the Content of the scope that matches the query, in their Metadata Provider's
/// order, with their texts in the Locale's language when it has them. A blank query matches nothing.
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
    fields(
        content.type = ?external_content_id.content_type(),
        content.external_id = %external_content_id.external_id(),
    ),
)]
pub async fn look_up(
    metadata_providers: &MetadataProviders,
    external_content_id: ExternalContentId,
    locale: Locale,
) -> Result<Content, LookUpError> {
    match external_content_id {
        ExternalContentId::Movie(id) => metadata_providers.tmdb.look_up_movie(id, locale).await,
        ExternalContentId::TvShow(id) => metadata_providers.tmdb.look_up_tv_show(id, locale).await,
        ExternalContentId::SportsEvent(id) => {
            metadata_providers.sportarr.look_up_sports_event(id).await
        }
        ExternalContentId::Book(id) => metadata_providers.hardcover.look_up_book(id).await,
    }
}
