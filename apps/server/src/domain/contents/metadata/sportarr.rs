//! sportarr.net: the Metadata Provider of Sports Events, the metadata service of Sportarr, whose
//! API needs no account.
//!
//! It knows Sports Events in English only, and limits each IP address to 300 searches and 20
//! lookups a minute.

use std::{
    fmt::{self, Display, Formatter},
    num::NonZeroU32,
};

use anyhow::Context;
use jiff::civil::Date;
use serde::{Deserialize, Deserializer};

use crate::{
    api_client::{ApiClient, ApiCredentials, ApiUrl, HttpClient},
    domain::contents::{
        ContentTranslations, CreditKind, ExternalContentId, Image, ImageSource, MediaTranslations,
        MediaType, SearchResult, SearchResults, Translations,
        metadata::{ContentMetadata, CreditMetadata, ExternalIds, MediaMetadata},
    },
};

/// The address of sportarr.net's API
const BASE_URL: &str = "https://sportarr.net/api/v2/json";

/// The width of sportarr.net's posters, in pixels. It doesn't say it, but they come from
/// TheSportsDB, whose posters are all 680 by 1000.
const POSTER_WIDTH: u32 = 680;

/// The height of sportarr.net's posters, in pixels
const POSTER_HEIGHT: u32 = 1000;

/// The width of sportarr.net's backdrops, in pixels. Like the posters, they come from TheSportsDB,
/// whose backdrops are all 1280 by 720.
const BACKDROP_WIDTH: u32 = 1280;

/// The height of sportarr.net's backdrops, in pixels
const BACKDROP_HEIGHT: u32 = 720;

/// The ID of a Sports Event at sportarr.net, such as `ev-028133`.
#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
pub struct SportarrId(String);

impl SportarrId {
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }
}

impl Display for SportarrId {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// sportarr.net. Clones share their connections.
#[derive(Clone, Debug)]
pub struct Sportarr {
    api: ApiClient,
}

impl Sportarr {
    /// Returns sportarr.net.
    pub fn new(http_client: &HttpClient) -> Self {
        let base_url = BASE_URL.parse().expect("BASE_URL is an API's URL");
        Self::with_base_url(http_client, base_url)
    }

    /// Returns a sportarr.net at another address, such as a fake one in tests.
    pub fn with_base_url(http_client: &HttpClient, base_url: ApiUrl) -> Self {
        Self {
            api: ApiClient::new(http_client, base_url, ApiCredentials::anonymous()),
        }
    }

    /// Returns the Sports Events whose title has the query's words in order, ignoring case and
    /// punctuation, the latest first: `moicano nolan` finds "UFC Fight Night 292 Moicano vs Nolan".
    ///
    /// sportarr.net sends every match at once, 25 at most, on the first page: the next ones have
    /// none.
    pub async fn search(&self, query: &str, page: NonZeroU32) -> anyhow::Result<SearchResults> {
        if page > NonZeroU32::MIN {
            return Ok(SearchResults::default());
        }

        let found: SearchEventsAnswer = self
            .api
            .get_required("/search/event/{pattern}", &[&title_pattern(query)], &[])
            .await
            .context("failed to search sportarr.net")?;

        let results = found.data.search.into_iter().map(search_result).collect();
        Ok(SearchResults {
            results,
            next_page: None,
        })
    }

    /// Returns the Sports Event with this ID, with its one Media, or None when sportarr.net doesn't
    /// know it. sportarr.net doesn't say which language its texts are in, so they're its original
    /// ones.
    pub async fn fetch_sports_event(
        &self,
        id: &SportarrId,
    ) -> anyhow::Result<Option<ContentMetadata>> {
        let found: Option<LookUpEventAnswer> = self
            .api
            .get("/lookup/event/{id}", &[&id.0], &[])
            .await
            .context("failed to fetch a Sports Event from sportarr.net")?;
        // sportarr.net answers an ID it doesn't know with no event, rather than with a 404
        let Some(event) = found.and_then(|found| found.data.into_iter().next()) else {
            return Ok(None);
        };

        let credits = event.league.map(|league| CreditMetadata {
            kind: CreditKind::League,
            name: league,
            character: None,
            photo: None,
            external_ids: ExternalIds::default(),
        });
        let media = MediaMetadata {
            media_type: MediaType::SportsEvent,
            group_number: None,
            number_in_group: None,
            release_date: event.date,
            runtime_seconds: None,
            image: None,
            texts: MediaTranslations::default(),
        };
        Ok(Some(ContentMetadata {
            id: ExternalContentId::SportsEvent(id.clone()),
            external_ids: ExternalIds::default(),
            original_title: event.title,
            original_language: None,
            origin_country: event.country,
            release_date: event.date,
            genres: Vec::new(),
            rating: None,
            backdrop: event.backdrop_url.and_then(backdrop),
            texts: ContentTranslations {
                overviews: Translations::original(event.description),
                posters: Translations::original(event.poster_url.and_then(poster)),
                ..ContentTranslations::default()
            },
            credits: credits.into_iter().collect(),
            media: vec![media],
        }))
    }
}

/// Returns the pattern of the titles that have the query's words in order, as sportarr.net
/// takes it: `%` stands for any text, in place of each run of spaces and punctuation.
fn title_pattern(query: &str) -> String {
    let mut pattern = String::with_capacity(query.len());
    for character in query.chars() {
        if character.is_alphanumeric() {
            pattern.push(character);
        } else if !pattern.ends_with('%') {
            pattern.push('%');
        }
    }
    pattern
}

/// Returns the search result a Sports Event of sportarr.net's search is.
fn search_result(event: Event) -> SearchResult {
    SearchResult {
        external_content_id: ExternalContentId::SportsEvent(event.id),
        title: event.title,
        date: event.date,
        // Leaves out the description, which is long, or only repeats the title, league and round
        overview: None,
        poster: event.poster_url.and_then(poster),
        creators: event.league.into_iter().collect(),
    }
}

/// Returns the poster at this URL, in the one size sportarr.net has.
fn poster(url: String) -> Option<Image> {
    Image::new([ImageSource {
        url,
        width: POSTER_WIDTH,
        height: POSTER_HEIGHT,
    }])
}

/// Returns the backdrop at this URL, in the one size sportarr.net has.
fn backdrop(url: String) -> Option<Image> {
    Image::new([ImageSource {
        url,
        width: BACKDROP_WIDTH,
        height: BACKDROP_HEIGHT,
    }])
}

/// sportarr.net's answer to a search.
#[derive(Debug, Deserialize)]
struct SearchEventsAnswer {
    data: SearchEventsData,
}

/// The Sports Events that match a search.
#[derive(Debug, Deserialize)]
struct SearchEventsData {
    /// The Sports Events, the latest first, or none when nothing matches
    search: Vec<Event>,
}

/// sportarr.net's answer to the lookup of a Sports Event.
#[derive(Debug, Deserialize)]
struct LookUpEventAnswer {
    /// The Sports Event, or nothing when sportarr.net doesn't know its ID
    data: Vec<Event>,
}

/// A Sports Event, in TheSportsDB's terms, which sportarr.net's API copies.
#[derive(Debug, Deserialize)]
struct Event {
    #[serde(rename = "idEvent")]
    id: SportarrId,
    #[serde(rename = "strEvent")]
    title: String,
    /// The league or competition it's part of, such as UFC or Formula 1
    #[serde(rename = "strLeague", default, deserialize_with = "optional_text")]
    league: Option<String>,
    /// The day it takes place
    #[serde(rename = "dateEvent", default, deserialize_with = "optional_date")]
    date: Option<Date>,
    #[serde(rename = "strPoster", default, deserialize_with = "optional_text")]
    poster_url: Option<String>,
    #[serde(rename = "strFanart", default, deserialize_with = "optional_text")]
    backdrop_url: Option<String>,
    /// The country it takes place in, such as `US`
    #[serde(rename = "strCountry", default, deserialize_with = "optional_text")]
    country: Option<String>,
    #[serde(
        rename = "strDescriptionEN",
        default,
        deserialize_with = "optional_text"
    )]
    description: Option<String>,
}

/// Reads a text that sportarr.net sends blank, or null, when it has none.
fn optional_text<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<String>, D::Error> {
    let text = Option::<String>::deserialize(deserializer)?;
    Ok(text
        .map(|text| text.trim().to_owned())
        .filter(|text| !text.is_empty()))
}

/// Reads a date that sportarr.net sends as `YYYY-MM-DD`, or blank, or null, when it has none.
fn optional_date<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<Date>, D::Error> {
    optional_text(deserializer)?
        .map(|date| date.parse().map_err(serde::de::Error::custom))
        .transpose()
}
