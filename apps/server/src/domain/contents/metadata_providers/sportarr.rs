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
    api_client::ApiClient,
    domain::{
        InternalError,
        contents::{
            Content, ContentId, Image, ImageSource, LookUpError, SearchResult, SearchResults,
        },
    },
};

/// The address of sportarr.net's API
const BASE_URL: &str = "https://sportarr.net/api/v2/json";

/// The width of sportarr.net's posters, in pixels. It doesn't say it, but they come from
/// TheSportsDB, whose posters are all 680 by 1000.
const POSTER_WIDTH: u32 = 680;

/// The height of sportarr.net's posters, in pixels
const POSTER_HEIGHT: u32 = 1000;

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
    pub fn new() -> anyhow::Result<Self> {
        Self::with_base_url(BASE_URL)
    }

    /// Returns a sportarr.net at another address, such as a fake one in tests.
    pub fn with_base_url(base_url: &str) -> anyhow::Result<Self> {
        Ok(Self {
            api: ApiClient::new(base_url, None)?,
        })
    }

    /// Returns the Sports Events whose title has the query's words in order, ignoring case and
    /// punctuation, the latest first: `moicano nolan` finds "UFC Fight Night 292 Moicano vs Nolan".
    ///
    /// sportarr.net sends every match at once, 25 at most, on the first page: the next ones have
    /// none.
    pub async fn search(
        &self,
        query: &str,
        page: NonZeroU32,
    ) -> Result<SearchResults, InternalError> {
        if page > NonZeroU32::MIN {
            return Ok(SearchResults::default());
        }

        let found: SearchEventsAnswer = self
            .api
            .get("/search/event/{pattern}", &[&title_pattern(query)], &[])
            .await?
            .context("sportarr.net answered GET /search/event/{pattern} with 404 Not Found")?;

        let results = found.data.search.into_iter().map(search_result).collect();
        Ok(SearchResults {
            results,
            next_page: None,
        })
    }

    /// Returns the Sports Event with this ID.
    pub async fn look_up_sports_event(&self, id: SportarrId) -> Result<Content, LookUpError> {
        let found: LookUpEventAnswer = self
            .api
            .get("/lookup/event/{id}", &[&id.0], &[])
            .await?
            .ok_or(LookUpError::NotFound)?;
        // sportarr.net answers an ID it doesn't know with no event, rather than with a 404
        let event = found.data.into_iter().next().ok_or(LookUpError::NotFound)?;

        Ok(Content {
            id: ContentId::SportsEvent(id),
            title: event.title,
        })
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
        id: ContentId::SportsEvent(event.id),
        title: event.title,
        date: event.date,
        overview: event.overview,
        poster: event.poster_url.and_then(poster),
        creators: Vec::new(),
        league: event.league,
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
    #[serde(
        rename = "strDescriptionEN",
        default,
        deserialize_with = "optional_text"
    )]
    overview: Option<String>,
    #[serde(rename = "strPoster", default, deserialize_with = "optional_text")]
    poster_url: Option<String>,
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
