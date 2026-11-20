//! TMDB's search for Movies and TV Shows.

use std::num::NonZeroU32;

use jiff::civil::Date;
use serde::Deserialize;

use super::{Tmdb, TmdbId, optional_date, optional_text, poster};
use crate::domain::{
    accounts::Locale,
    contents::{ExternalContentId, SearchResult, SearchResults},
};

/// The last page of results TMDB serves, whatever their number
const LAST_PAGE: u32 = 500;

/// The number of TMDB's pages a search reads at most to find some Content, as some only have people
const MAX_PAGES_READ: u32 = 5;

impl Tmdb {
    /// Returns a page of the Movies and TV Shows whose title matches the query, most relevant
    /// first, with their texts in the Locale's language. It leaves out adult content, and the
    /// videos: what TMDB lists as movies but flags as not truly ones, such as filmed sports events,
    /// concerts and compilations.
    ///
    /// TMDB's pages also list people, who aren't Content: when one has only people and videos, the
    /// search reads the next one, up to `MAX_PAGES_READ`, so that the apps don't load pages that
    /// show nothing.
    pub async fn search(
        &self,
        query: &str,
        mut page: NonZeroU32,
        locale: Locale,
    ) -> anyhow::Result<SearchResults> {
        let mut pages_read = 1;
        loop {
            let page_number = page.to_string();
            let params = [
                ("query", query),
                ("page", &page_number),
                ("include_adult", "false"),
                ("language", locale.language_tag()),
            ];
            let found: MultiSearchPage =
                self.api.get_required("/search/multi", &[], &params).await?;

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
}

/// Returns the Content a result of TMDB's search is, or None for a person or a video.
fn search_result(result: MultiSearchResult) -> Option<SearchResult> {
    match result {
        MultiSearchResult::Movie(movie) if movie.video => None,
        MultiSearchResult::Movie(movie) => Some(SearchResult {
            external_content_id: ExternalContentId::Movie(TmdbId(movie.id)),
            title: movie.title,
            date: movie.release_date,
            overview: movie.overview,
            poster: movie.poster_path.as_deref().and_then(poster),
            // TMDB's search doesn't say who makes them
            creators: Vec::new(),
        }),
        MultiSearchResult::TvShow(tv_show) => Some(SearchResult {
            external_content_id: ExternalContentId::TvShow(TmdbId(tv_show.id)),
            title: tv_show.name,
            date: tv_show.first_air_date,
            overview: tv_show.overview,
            poster: tv_show.poster_path.as_deref().and_then(poster),
            // TMDB's search doesn't say who makes them
            creators: Vec::new(),
        }),
        MultiSearchResult::Person => None,
    }
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
