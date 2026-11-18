//! TMDB's answers to searches, and to finds by another site's ID.

use std::num::NonZeroU32;

use jiff::civil::Date;
use serde::Deserialize;

use super::{optional_date, optional_text};

/// The last page of results TMDB serves, whatever their number
const LAST_PAGE: u32 = 500;

/// A page of a search's results.
#[derive(Clone, Debug, Deserialize)]
pub struct SearchPage<T> {
    /// The page's number, from 1
    pub page: u32,
    pub results: Vec<T>,
    /// The number of pages, of which TMDB serves the first 500
    pub total_pages: u32,
    pub total_results: u32,
}

impl<T> SearchPage<T> {
    /// Returns the number of the next page TMDB serves, or None on the last one.
    pub fn next_page(&self) -> Option<NonZeroU32> {
        NonZeroU32::new(self.page)
            .and_then(|page| page.checked_add(1))
            .filter(|next| next.get() <= self.total_pages.min(LAST_PAGE))
    }
}

/// A result of a search for Movies, TV Shows and people.
#[derive(Clone, Debug, Deserialize)]
#[serde(tag = "media_type", rename_all = "lowercase")]
pub enum MultiSearchResult {
    Movie(MovieSearchResult),
    #[serde(rename = "tv")]
    TvShow(TvShowSearchResult),
    Person(PersonSearchResult),
}

/// A Movie in search results, with its texts in the search's language.
#[derive(Clone, Debug, Deserialize)]
pub struct MovieSearchResult {
    pub id: u32,
    pub title: String,
    pub original_title: String,
    /// The ISO 639-1 code of its original language
    pub original_language: String,
    #[serde(default, deserialize_with = "optional_text")]
    pub overview: Option<String>,
    pub poster_path: Option<String>,
    pub backdrop_path: Option<String>,
    #[serde(default)]
    pub genre_ids: Vec<u32>,
    pub popularity: f64,
    #[serde(default, deserialize_with = "optional_date")]
    pub release_date: Option<Date>,
    /// Whether it's a video rather than a film, such as a concert
    #[serde(default)]
    pub video: bool,
    pub vote_average: f64,
    pub vote_count: u32,
    pub adult: bool,
}

/// A TV Show in search results, with its texts in the search's language.
#[derive(Clone, Debug, Deserialize)]
pub struct TvShowSearchResult {
    pub id: u32,
    pub name: String,
    pub original_name: String,
    /// The ISO 639-1 code of its original language
    pub original_language: String,
    #[serde(default, deserialize_with = "optional_text")]
    pub overview: Option<String>,
    pub poster_path: Option<String>,
    pub backdrop_path: Option<String>,
    #[serde(default)]
    pub genre_ids: Vec<u32>,
    pub popularity: f64,
    #[serde(default, deserialize_with = "optional_date")]
    pub first_air_date: Option<Date>,
    /// The ISO 3166-1 codes of the countries it comes from
    #[serde(default)]
    pub origin_country: Vec<String>,
    pub vote_average: f64,
    pub vote_count: u32,
    pub adult: bool,
}

/// A person in search results, such as an actor.
#[derive(Clone, Debug, Deserialize)]
pub struct PersonSearchResult {
    pub id: u32,
    pub name: String,
    pub original_name: String,
    /// 0 when unknown, 1 for women, 2 for men, 3 for non-binary people
    pub gender: Option<u8>,
    /// The work they're best known for, such as `Acting`
    pub known_for_department: Option<String>,
    pub profile_path: Option<String>,
    pub popularity: f64,
    #[serde(default)]
    pub known_for: Vec<KnownFor>,
    pub adult: bool,
}

/// A Movie or a TV Show a person is known for.
#[derive(Clone, Debug, Deserialize)]
#[serde(tag = "media_type", rename_all = "lowercase")]
pub enum KnownFor {
    Movie(MovieSearchResult),
    #[serde(rename = "tv")]
    TvShow(TvShowSearchResult),
}

/// The Movies, TV Shows and episodes that another site's ID points to.
#[derive(Clone, Debug, Deserialize)]
pub struct FindResults {
    #[serde(default)]
    pub movie_results: Vec<MovieSearchResult>,
    #[serde(default)]
    pub tv_results: Vec<TvShowSearchResult>,
    #[serde(default)]
    pub tv_episode_results: Vec<TvEpisodeResult>,
}

/// An episode found by another site's ID, such as a TheTVDB episode ID.
#[derive(Clone, Debug, Deserialize)]
pub struct TvEpisodeResult {
    /// The TMDB ID of its TV Show
    pub show_id: u32,
    pub season_number: u32,
    pub episode_number: u32,
}
