//! Content: the Movies, TV Shows, Sports Events and Books that Users search for and open, from the
//! Metadata Providers.
//!
//! The first view of a Content saves it, with its Media, and later views read what's saved. A view
//! of a Content saved over a day ago queues a job that saves it again, so pages never wait for a
//! Metadata Provider once their Content is saved.

mod image;
mod localizations;
mod metadata_providers;
mod store;

use std::{
    fmt::{self, Display, Formatter},
    num::NonZeroU32,
};

use jiff::{SignedDuration, Timestamp, civil::Date};
use serde::{Deserialize, Serialize};
use tracing::Level;
use utoipa::{
    PartialSchema, ToSchema,
    openapi::{RefOr, Schema},
};
use uuid::Uuid;

pub use self::{
    image::{Image, ImageSource},
    localizations::{ContentTranslations, Language, MediaTranslations, Translations},
    metadata_providers::{
        ContentMetadata, CreditMetadata, ExternalIds, Hardcover, HardcoverId, MediaMetadata,
        MetadataProviders, Sportarr, SportarrId, Tmdb, TmdbId,
    },
    store::list_media,
};
use super::{InternalError, accounts::Locale};
use crate::{
    db::Pool,
    jobs::{self, RefreshContent},
};

/// The time after which a view of a Content queues a job that saves it again
const REFRESH_AFTER: SignedDuration = SignedDuration::from_hours(24);

/// The unique ID of a Content in WatchClub. Actions take it rather than an External ID, which a
/// Metadata Provider can change.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[sqlx(transparent)]
pub struct ContentId(Uuid);

impl Display for ContentId {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// The unique ID of a Media.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[sqlx(transparent)]
pub struct MediaId(Uuid);

/// The type of a Content.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, sqlx::Type, ToSchema)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "content_type", rename_all = "snake_case")]
pub enum ContentType {
    Movie,
    TvShow,
    SportsEvent,
    Book,
}

impl ContentType {
    /// Returns the Metadata Provider that Content of this type comes from.
    pub const fn metadata_provider(self) -> MetadataProvider {
        match self {
            Self::Movie | Self::TvShow => MetadataProvider::Tmdb,
            Self::SportsEvent => MetadataProvider::Sportarr,
            Self::Book => MetadataProvider::Hardcover,
        }
    }
}

/// A catalog that Content metadata comes from.
#[derive(Clone, Copy, Debug, PartialEq, Eq, sqlx::Type)]
#[sqlx(type_name = "metadata_provider", rename_all = "snake_case")]
pub enum MetadataProvider {
    Tmdb,
    Sportarr,
    Hardcover,
}

/// The kind of a Media, which tells the Content Type it belongs to.
#[derive(Clone, Copy, Debug, PartialEq, Eq, sqlx::Type)]
#[sqlx(type_name = "media_type", rename_all = "snake_case")]
pub enum MediaType {
    Movie,
    TvShowEpisode,
    SportsEvent,
}

/// A kind of story a Movie or a TV Show tells.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, sqlx::Type, ToSchema)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "genre", rename_all = "snake_case")]
pub enum Genre {
    Action,
    Adventure,
    Animation,
    Comedy,
    Crime,
    Documentary,
    Drama,
    Family,
    Fantasy,
    History,
    Horror,
    Kids,
    Music,
    Mystery,
    News,
    Politics,
    Reality,
    Romance,
    ScienceFiction,
    Soap,
    Talk,
    Thriller,
    TvMovie,
    War,
    Western,
}

/// The part a person or an organization has in a Content.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, sqlx::Type, ToSchema)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "credit_kind", rename_all = "snake_case")]
pub enum CreditKind {
    Director,
    Actor,
    Author,
    Illustrator,
    Narrator,
    Artist,
    /// The league or competition a Sports Event is part of
    League,
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

/// A Content as its page shows it, with its texts in one Locale.
#[derive(Clone, Debug, PartialEq, Serialize, ToSchema)]
pub struct Content {
    pub id: ContentId,
    #[serde(flatten)]
    pub external_content_id: ExternalContentId,
    pub title: String,
    /// Its title in its original language
    pub original_title: String,
    /// Its original language, as an ISO 639-1 code such as `fr`
    #[schema(required = true)]
    pub original_language: Option<String>,
    #[schema(required = true)]
    pub overview: Option<String>,
    #[schema(required = true)]
    pub poster: Option<Image>,
    #[schema(required = true)]
    pub backdrop: Option<Image>,
    /// The day it came out, first aired or takes place
    #[schema(value_type = Option<String>, format = Date, required = true)]
    pub release_date: Option<Date>,
    pub genres: Vec<Genre>,
    /// The average of its votes out of 10, to one decimal, or null when too few people voted
    #[schema(required = true)]
    pub rating: Option<f32>,
    /// The YouTube URL of its trailer
    #[schema(required = true)]
    pub trailer_url: Option<String>,
    /// Who made it and who's in it, in display order
    pub credits: Vec<Credit>,
    /// The runtime of its Media, when it has only one, such as a Movie
    #[schema(required = true)]
    pub runtime_seconds: Option<i32>,
    /// The number of groups its Media are in, such as a TV Show's seasons
    pub media_group_count: i32,
}

/// A person or an organization who made a Content or is in it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct Credit {
    pub kind: CreditKind,
    pub name: String,
    /// The character an actor plays
    #[schema(required = true)]
    pub character: Option<String>,
    #[schema(required = true)]
    pub photo: Option<Image>,
}

/// A Media of a Content, such as a TV Show Episode, with its texts in one Locale.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct Media {
    pub id: MediaId,
    /// The group it's in, such as a TV Show Episode's season
    #[schema(required = true)]
    pub group_number: Option<i32>,
    /// Its number in its group, such as a TV Show Episode's
    #[schema(required = true)]
    pub number: Option<i32>,
    #[schema(required = true)]
    pub title: Option<String>,
    #[schema(required = true)]
    pub overview: Option<String>,
    #[schema(required = true)]
    pub image: Option<Image>,
    /// The day it came out or aired, which tells whether it's out
    #[schema(value_type = Option<String>, format = Date, required = true)]
    pub release_date: Option<Date>,
    #[schema(required = true)]
    pub runtime_seconds: Option<i32>,
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

/// The failures of finding a Content by its External ID.
#[derive(Debug, thiserror::Error)]
pub enum LookUpError {
    /// Its Metadata Provider has no such Content
    #[error("no such Content")]
    NotFound,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

impl From<InternalError> for LookUpError {
    fn from(error: InternalError) -> Self {
        Self::Internal(error.0)
    }
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

/// Returns the Content in the Locale. The first time someone opens it, it's saved from its
/// Metadata Provider first. When it was saved over a day ago, it's returned at once, and a job
/// saves it again for the next views.
#[tracing::instrument(
    skip_all,
    fields(
        content.type = ?external_content_id.content_type(),
        content.external_id = %external_content_id.external_id(),
    ),
)]
pub async fn get_by_external_id(
    db: &Pool,
    metadata_providers: &MetadataProviders,
    external_content_id: ExternalContentId,
    locale: Locale,
) -> Result<Content, LookUpError> {
    if let Some(saved) = store::find(db, &external_content_id, locale).await? {
        if saved.refreshed_at < Timestamp::now() - REFRESH_AFTER {
            let content_id = saved.content.id;
            jobs::enqueue(db, RefreshContent { content_id }).await?;
        }
        return Ok(saved.content);
    }

    let metadata = metadata_providers.fetch(&external_content_id).await?;
    store::save(db, &metadata).await?;
    let saved = store::find(db, &external_content_id, locale)
        .await?
        .ok_or_else(|| anyhow::anyhow!("the Content just saved is missing"))?;
    Ok(saved.content)
}

/// Saves the Content again, as its Metadata Provider has it now. When its Metadata Provider no
/// longer knows it, such as after deleting a duplicate, the Content stays as it is. Does nothing
/// when there's no such Content.
#[tracing::instrument(skip_all, fields(content.id = %content_id))]
pub async fn refresh(
    db: &Pool,
    metadata_providers: &MetadataProviders,
    content_id: ContentId,
) -> Result<(), InternalError> {
    let Some(external_content_id) = store::external_content_id(db, content_id).await? else {
        return Ok(());
    };

    match metadata_providers.fetch(&external_content_id).await {
        Ok(metadata) => {
            store::save(db, &metadata).await?;
        }
        Err(LookUpError::NotFound) => {
            tracing::event!(
                name: "contents.refresh.not_found",
                Level::WARN,
                content.type = ?external_content_id.content_type(),
                content.external_id = %external_content_id.external_id(),
                "its Metadata Provider no longer knows the Content, which stays as it is",
            );
        }
        Err(LookUpError::Internal(error)) => return Err(error.into()),
    }
    Ok(())
}
