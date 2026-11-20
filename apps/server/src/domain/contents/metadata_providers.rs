//! The Metadata Providers, the catalogs that Content comes from. Each has a gateway that calls it
//! for what WatchClub needs, in WatchClub's terms: a search's results, or a Content's metadata,
//! which saving writes whatever its Metadata Provider.

mod hardcover;
mod sportarr;
mod tmdb;

use jiff::civil::Date;
use serde::{Deserialize, Serialize};

pub use self::{
    hardcover::{Hardcover, HardcoverId},
    sportarr::{Sportarr, SportarrId},
    tmdb::{Tmdb, TmdbId},
};
use super::{
    ContentTranslations, CreditKind, ExternalContentId, Genre, Image, LookUpContentError,
    MediaTranslations, MediaType, MetadataProvider,
};

/// The Metadata Providers that the instance finds Content in.
#[derive(Clone, Debug)]
pub struct MetadataProviders {
    /// The Metadata Provider of Movies and TV Shows
    pub tmdb: Tmdb,
    /// The Metadata Provider of Sports Events
    pub sportarr: Sportarr,
    /// The Metadata Provider of Books
    pub hardcover: Hardcover,
}

impl MetadataProviders {
    /// Returns what the Content's Metadata Provider knows of it now, in every language it has.
    pub(super) async fn fetch(
        &self,
        external_content_id: &ExternalContentId,
    ) -> Result<ContentMetadata, LookUpContentError> {
        match external_content_id {
            ExternalContentId::Movie(id) => self.tmdb.fetch_movie(*id).await,
            ExternalContentId::TvShow(id) => self.tmdb.fetch_tv_show(*id).await,
            ExternalContentId::SportsEvent(id) => self.sportarr.fetch_sports_event(id).await,
            ExternalContentId::Book(id) => self.hardcover.fetch_book(*id).await,
        }
    }
}

/// A Content as its Metadata Provider describes it, in WatchClub's terms: what saving it writes,
/// whatever its type.
#[derive(Clone, Debug, PartialEq)]
pub struct ContentMetadata {
    pub id: ExternalContentId,
    /// Its IDs in other catalogs, such as IMDb's. Saving adds `id`'s
    pub external_ids: ExternalIds,
    pub original_title: String,
    /// An ISO 639-1 code, such as `fr`
    pub original_language: Option<String>,
    /// An ISO 3166-1 code, such as `FR`
    pub origin_country: Option<String>,
    /// The day it came out, first aired or takes place
    pub release_date: Option<Date>,
    pub genres: Vec<Genre>,
    /// The average of its votes out of 10, to one decimal, when enough people voted
    pub rating: Option<f32>,
    pub backdrop: Option<Image>,
    pub texts: ContentTranslations,
    /// Who made it and who's in it, in display order
    pub credits: Vec<CreditMetadata>,
    /// What Users play inside it, each once
    pub media: Vec<MediaMetadata>,
}

/// A person or an organization who made a Content or is in it, as its Metadata Provider describes
/// them.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CreditMetadata {
    pub kind: CreditKind,
    pub name: String,
    /// The character an actor plays
    pub character: Option<String>,
    pub photo: Option<Image>,
    /// Their IDs in outside catalogs
    pub external_ids: ExternalIds,
}

/// A Media as its Metadata Provider describes it, such as a TV Show Episode.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MediaMetadata {
    pub media_type: MediaType,
    /// The group it's in, such as a TV Show Episode's season
    pub group_number: Option<i32>,
    /// Its number in its group, such as a TV Show Episode's
    pub number_in_group: Option<i32>,
    /// The day it came out or aired
    pub release_date: Option<Date>,
    pub runtime_seconds: Option<i32>,
    pub image: Option<Image>,
    pub texts: MediaTranslations,
}

/// The IDs of a Content or a person in outside catalogs, as the database stores them.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct ExternalIds {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tmdb: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub imdb: Option<String>,
    /// TheTVDB's
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tvdb: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sportarr: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub hardcover: Option<String>,
}

impl ExternalIds {
    /// Returns these IDs with a Content's External ID at its Metadata Provider.
    pub(super) fn with(mut self, external_content_id: &ExternalContentId) -> Self {
        let id = Some(external_content_id.external_id());
        match external_content_id.content_type().metadata_provider() {
            MetadataProvider::Tmdb => self.tmdb = id,
            MetadataProvider::Sportarr => self.sportarr = id,
            MetadataProvider::Hardcover => self.hardcover = id,
        }
        self
    }
}
