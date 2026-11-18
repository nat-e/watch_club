//! TMDB's JSON: the parts of its answers that WatchClub reads.

use std::num::NonZeroU32;

use jiff::civil::Date;
use serde::{Deserialize, Deserializer};

/// The last page of results TMDB serves, whatever their number
const LAST_PAGE: u32 = 500;

/// A page of the results of a search for Movies, TV Shows and people.
#[derive(Debug, Deserialize)]
pub(super) struct SearchPage {
    /// The page's number, from 1
    page: u32,
    pub(super) results: Vec<SearchResult>,
    /// The number of pages, of which TMDB serves the first 500
    total_pages: u32,
}

impl SearchPage {
    /// Returns the number of the next page TMDB serves, or None on the last one.
    pub(super) fn next_page(&self) -> Option<NonZeroU32> {
        NonZeroU32::new(self.page)
            .and_then(|page| page.checked_add(1))
            .filter(|next| next.get() <= self.total_pages.min(LAST_PAGE))
    }
}

/// A result of a search for Movies, TV Shows and people.
#[derive(Debug, Deserialize)]
#[serde(tag = "media_type", rename_all = "lowercase")]
pub(super) enum SearchResult {
    Movie(MovieResult),
    #[serde(rename = "tv")]
    TvShow(TvShowResult),
    Person,
}

/// A Movie in search results, with its texts in the search's language.
#[derive(Debug, Deserialize)]
pub(super) struct MovieResult {
    pub(super) id: u32,
    pub(super) title: String,
    #[serde(default, deserialize_with = "optional_text")]
    pub(super) overview: Option<String>,
    pub(super) poster_path: Option<String>,
    #[serde(default, deserialize_with = "optional_date")]
    pub(super) release_date: Option<Date>,
}

/// A TV Show in search results, with its texts in the search's language.
#[derive(Debug, Deserialize)]
pub(super) struct TvShowResult {
    pub(super) id: u32,
    pub(super) name: String,
    #[serde(default, deserialize_with = "optional_text")]
    pub(super) overview: Option<String>,
    pub(super) poster_path: Option<String>,
    #[serde(default, deserialize_with = "optional_date")]
    pub(super) first_air_date: Option<Date>,
}

/// A Movie's details, with its texts in the details' language.
#[derive(Debug, Deserialize)]
pub(super) struct Movie {
    pub(super) title: String,
}

/// A TV Show's details, with its texts in the details' language.
#[derive(Debug, Deserialize)]
pub(super) struct TvShow {
    pub(super) name: String,
}

/// The body of TMDB's failures.
#[derive(Debug, Deserialize)]
pub(super) struct ErrorBody {
    pub(super) status_message: String,
}

/// Reads a text that TMDB sends empty, or null, when it has none.
fn optional_text<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<String>, D::Error> {
    let text = Option::<String>::deserialize(deserializer)?;
    Ok(text.filter(|text| !text.is_empty()))
}

/// Reads a date that TMDB sends as `YYYY-MM-DD`, or empty, or null, when it has none.
fn optional_date<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<Date>, D::Error> {
    optional_text(deserializer)?
        .map(|date| date.parse().map_err(serde::de::Error::custom))
        .transpose()
}
