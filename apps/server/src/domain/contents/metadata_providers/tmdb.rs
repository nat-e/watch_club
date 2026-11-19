//! TMDB, The Movie Database: the Metadata Provider of Movies and TV Shows.

use std::{
    fmt::{self, Display, Formatter},
    num::{NonZeroU32, ParseIntError},
    str::FromStr,
};

use anyhow::Context;
use jiff::civil::Date;
use secrecy::SecretString;
use serde::{Deserialize, Deserializer};

use crate::{
    api_client::ApiClient,
    domain::{
        InternalError,
        accounts::Locale,
        contents::{
            Content, ContentId, Image, ImageSource, LookUpError, SearchResult, SearchResults,
        },
    },
};

/// The address of TMDB's API
const BASE_URL: &str = "https://api.themoviedb.org/3";

/// The address of TMDB's images, which a size and an image's path follow
const IMAGES_URL: &str = "https://image.tmdb.org/t/p";

/// The widths of TMDB's posters, in pixels. It also has the original, whose size it doesn't say.
const POSTER_WIDTHS: [u32; 6] = [92, 154, 185, 342, 500, 780];

/// The last page of results TMDB serves, whatever their number
const LAST_PAGE: u32 = 500;

/// The number of TMDB's pages a search reads at most to find some Content, as some only have people
const MAX_PAGES_READ: u32 = 5;

/// The ID of a Movie or a TV Show at TMDB, which numbers Movies and TV Shows apart: a Movie and a TV
/// Show can have the same.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TmdbId(u32);

impl TmdbId {
    pub const fn new(id: u32) -> Self {
        Self(id)
    }
}

impl FromStr for TmdbId {
    type Err = ParseIntError;

    fn from_str(text: &str) -> Result<Self, Self::Err> {
        text.parse().map(Self)
    }
}

impl Display for TmdbId {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// TMDB, signed in with the API Read Access Token of the instance. Clones share their connections.
#[derive(Clone, Debug)]
pub struct Tmdb {
    api: ApiClient,
}

impl Tmdb {
    /// Returns TMDB, signed in with `token`, the instance's API Read Access Token.
    pub fn new(token: &SecretString) -> anyhow::Result<Self> {
        Self::with_base_url(token, BASE_URL)
    }

    /// Returns a TMDB at another address, such as a fake one in tests.
    pub fn with_base_url(token: &SecretString, base_url: &str) -> anyhow::Result<Self> {
        Ok(Self {
            api: ApiClient::new(base_url, Some(token))?,
        })
    }

    /// Returns a page of the Movies and TV Shows whose title matches the query, most relevant
    /// first, with their texts in the Locale's language. It leaves out adult content, and the
    /// videos: what TMDB lists as movies but flags as not truly ones, such as filmed sports events,
    /// concerts and compilations. Sports Events come from sportarr.net instead.
    ///
    /// TMDB's pages also list people, who aren't Content: when one has only people and videos, the
    /// search reads the next one, up to `MAX_PAGES_READ`, so that the apps don't load pages that
    /// show nothing.
    pub async fn search(
        &self,
        query: &str,
        mut page: NonZeroU32,
        locale: Locale,
    ) -> Result<SearchResults, InternalError> {
        let mut pages_read = 1;
        loop {
            let page_number = page.to_string();
            let params = [
                ("query", query),
                ("page", &page_number),
                ("include_adult", "false"),
                ("language", locale.language_tag()),
            ];
            let found: MultiSearchPage = self
                .api
                .get("/search/multi", &[], &params)
                .await?
                .context("TMDB answered GET /search/multi with 404 Not Found")?;

            let next_page = found.next_page();
            let results: Vec<_> = found
                .results
                .into_iter()
                .filter_map(search_result)
                .collect();

            match next_page {
                Some(next_page) if results.is_empty() && pages_read < MAX_PAGES_READ => {
                    page = next_page;
                    pages_read += 1;
                }
                _ => return Ok(SearchResults { results, next_page }),
            }
        }
    }

    /// Returns the Movie with this ID, with its title in the Locale's language.
    pub async fn look_up_movie(&self, id: TmdbId, locale: Locale) -> Result<Content, LookUpError> {
        let movie: MovieDetails = self
            .api
            .get(
                "/movie/{id}",
                &[&id.to_string()],
                &[("language", locale.language_tag())],
            )
            .await?
            .ok_or(LookUpError::NotFound)?;

        Ok(Content {
            id: ContentId::Movie(id),
            title: movie.title,
        })
    }

    /// Returns the TV Show with this ID, with its title in the Locale's language.
    pub async fn look_up_tv_show(
        &self,
        id: TmdbId,
        locale: Locale,
    ) -> Result<Content, LookUpError> {
        let tv_show: TvShowDetails = self
            .api
            .get(
                "/tv/{id}",
                &[&id.to_string()],
                &[("language", locale.language_tag())],
            )
            .await?
            .ok_or(LookUpError::NotFound)?;

        Ok(Content {
            id: ContentId::TvShow(id),
            title: tv_show.name,
        })
    }
}

/// Returns the Content a result of TMDB's search is, or None for a person or a video.
fn search_result(result: MultiSearchResult) -> Option<SearchResult> {
    match result {
        MultiSearchResult::Movie(movie) if movie.video => None,
        MultiSearchResult::Movie(movie) => Some(SearchResult {
            id: ContentId::Movie(TmdbId(movie.id)),
            title: movie.title,
            date: movie.release_date,
            overview: movie.overview,
            poster: movie.poster_path.as_deref().and_then(poster),
            creators: Vec::new(),
        }),
        MultiSearchResult::TvShow(tv_show) => Some(SearchResult {
            id: ContentId::TvShow(TmdbId(tv_show.id)),
            title: tv_show.name,
            date: tv_show.first_air_date,
            overview: tv_show.overview,
            poster: tv_show.poster_path.as_deref().and_then(poster),
            creators: Vec::new(),
        }),
        MultiSearchResult::Person => None,
    }
}

/// Returns the poster at this path on TMDB's image server, in each of its sizes.
fn poster(path: &str) -> Option<Image> {
    Image::new(POSTER_WIDTHS.map(|width| ImageSource {
        url: format!("{IMAGES_URL}/w{width}{path}"),
        width,
        // TMDB doesn't say it: most posters are 2:3
        height: (width * 3).div_ceil(2),
    }))
}

/// A page of the results of a search for Movies, TV Shows and people.
#[derive(Debug, Deserialize)]
struct MultiSearchPage {
    /// The page's number, from 1
    page: u32,
    results: Vec<MultiSearchResult>,
    /// The number of pages, of which TMDB serves the first 500
    total_pages: u32,
}

impl MultiSearchPage {
    /// Returns the number of the next page TMDB serves, or None on the last one.
    fn next_page(&self) -> Option<NonZeroU32> {
        NonZeroU32::new(self.page)
            .and_then(|page| page.checked_add(1))
            .filter(|next| next.get() <= self.total_pages.min(LAST_PAGE))
    }
}

/// A result of a search for Movies, TV Shows and people.
#[derive(Debug, Deserialize)]
#[serde(tag = "media_type", rename_all = "lowercase")]
enum MultiSearchResult {
    Movie(MovieResult),
    #[serde(rename = "tv")]
    TvShow(TvShowResult),
    Person,
}

/// A Movie in search results, with its texts in the search's language.
#[derive(Debug, Deserialize)]
struct MovieResult {
    id: u32,
    title: String,
    #[serde(default, deserialize_with = "optional_text")]
    overview: Option<String>,
    poster_path: Option<String>,
    #[serde(default, deserialize_with = "optional_date")]
    release_date: Option<Date>,
    /// Whether TMDB flags it as a video rather than a movie, such as a filmed sports event, a
    /// concert or a compilation
    #[serde(default)]
    video: bool,
}

/// A TV Show in search results, with its texts in the search's language.
#[derive(Debug, Deserialize)]
struct TvShowResult {
    id: u32,
    name: String,
    #[serde(default, deserialize_with = "optional_text")]
    overview: Option<String>,
    poster_path: Option<String>,
    #[serde(default, deserialize_with = "optional_date")]
    first_air_date: Option<Date>,
}

/// A Movie's details, with its texts in the details' language.
#[derive(Debug, Deserialize)]
struct MovieDetails {
    title: String,
}

/// A TV Show's details, with its texts in the details' language.
#[derive(Debug, Deserialize)]
struct TvShowDetails {
    name: String,
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
