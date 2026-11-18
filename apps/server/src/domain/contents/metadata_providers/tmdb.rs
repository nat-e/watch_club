//! TMDB, The Movie Database: the Metadata Provider of Movies and TV Shows.

mod api;

use std::{
    fmt::{self, Display, Formatter},
    num::{NonZeroU32, ParseIntError},
    str::FromStr,
};

use anyhow::Context;
use jiff::civil::Date;
use secrecy::SecretString;

use crate::{
    api_client::ApiClient,
    domain::{
        InternalError,
        accounts::Locale,
        contents::{Content, ContentId, LookUpError, SearchResult, SearchResults},
    },
};

/// The address of TMDB's API
const BASE_URL: &str = "https://api.themoviedb.org/3";

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
            api: ApiClient::new(base_url, token)?,
        })
    }

    /// Returns a page of the Movies and TV Shows whose title matches the query, most relevant
    /// first, with their texts in the Locale's language. It leaves out adult content.
    ///
    /// TMDB's pages also list people, who aren't Content: when one has only people, the search reads
    /// the next one, up to `MAX_PAGES_READ`, so that the apps don't load pages that show nothing.
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
            let found: api::SearchPage = self
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
        let movie: api::Movie = self
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
        let tv_show: api::TvShow = self
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

/// Returns the Content a result of TMDB's search is, or None for a person.
fn search_result(result: api::SearchResult) -> Option<SearchResult> {
    match result {
        api::SearchResult::Movie(movie) => Some(SearchResult {
            id: ContentId::Movie(TmdbId(movie.id)),
            title: movie.title,
            year: movie.release_date.map(Date::year),
            overview: movie.overview,
            poster_path: movie.poster_path,
        }),
        api::SearchResult::TvShow(tv_show) => Some(SearchResult {
            id: ContentId::TvShow(TmdbId(tv_show.id)),
            title: tv_show.name,
            year: tv_show.first_air_date.map(Date::year),
            overview: tv_show.overview,
            poster_path: tv_show.poster_path,
        }),
        api::SearchResult::Person => None,
    }
}
