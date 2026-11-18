//! Hardcover: the Metadata Provider of Books.

mod api;

use std::{
    fmt::{self, Display, Formatter},
    num::{NonZeroU32, ParseIntError},
    str::FromStr,
};

use secrecy::{ExposeSecret, SecretString};
use serde::Serialize;

use crate::{
    api_client::ApiClient,
    domain::{
        InternalError,
        contents::{
            Content, ContentId, Image, ImageSource, LookUpError, SearchResult, SearchResults,
        },
    },
};

/// The address of Hardcover's API
const BASE_URL: &str = "https://api.hardcover.app/v1";

/// The number of Books on a page of search results
const PAGE_SIZE: u32 = 20;

/// The roles of the people a Book credits that make them its creators, leaving out roles such as
/// translator or narrator. Hardcover's roles are free text, which some Books write otherwise
const CREATOR_ROLES: [&str; 3] = ["Author", "Illustrator", "Illustrations"];

/// The ID of a Book at Hardcover.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
pub struct HardcoverId(u32);

impl HardcoverId {
    pub const fn new(id: u32) -> Self {
        Self(id)
    }
}

impl FromStr for HardcoverId {
    type Err = ParseIntError;

    fn from_str(text: &str) -> Result<Self, Self::Err> {
        text.parse().map(Self)
    }
}

impl Display for HardcoverId {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// Hardcover, signed in with the API token of the instance's Hardcover account. Clones share their
/// connections.
///
/// Hardcover has no Locale: Books have the title and description it knows them by, often in English.
#[derive(Clone, Debug)]
pub struct Hardcover {
    api: ApiClient,
}

impl Hardcover {
    /// Returns Hardcover, signed in with `token`, the API token of the instance's Hardcover account.
    pub fn new(token: &SecretString) -> anyhow::Result<Self> {
        Self::with_base_url(token, BASE_URL)
    }

    /// Returns a Hardcover at another address, such as a fake one in tests.
    pub fn with_base_url(token: &SecretString, base_url: &str) -> anyhow::Result<Self> {
        // Hardcover shows the token after `Bearer `, so hosts may copy both
        let token = token.expose_secret();
        let token = token.strip_prefix("Bearer ").unwrap_or(token).trim();
        Ok(Self {
            api: ApiClient::new(base_url, &SecretString::from(token))?,
        })
    }

    /// Returns a page of the Books whose title, series, authors or ISBN match the query, most
    /// relevant first.
    pub async fn search(
        &self,
        query: &str,
        page: NonZeroU32,
    ) -> Result<SearchResults, InternalError> {
        let variables = api::SearchBooksVariables {
            query,
            page,
            per_page: PAGE_SIZE,
        };
        let data: api::SearchBooks = api::query(&self.api, api::SEARCH_BOOKS, variables).await?;
        let found = data.search.results;

        let has_more = u64::from(page.get()) * u64::from(PAGE_SIZE) < u64::from(found.found);
        let next_page = page.checked_add(1).filter(|_| has_more);
        let results = found
            .hits
            .into_iter()
            .map(|hit| search_result(hit.document))
            .collect();
        Ok(SearchResults { results, next_page })
    }

    /// Returns the Book with this ID.
    pub async fn look_up_book(&self, id: HardcoverId) -> Result<Content, LookUpError> {
        let data: api::BookData =
            api::query(&self.api, api::BOOK, api::BookVariables { id }).await?;
        let book = data.books_by_pk.ok_or(LookUpError::NotFound)?;

        Ok(Content {
            id: ContentId::Book(id),
            title: book.title,
        })
    }
}

/// Returns the search result a Book of Hardcover's search is.
fn search_result(book: api::BookDocument) -> SearchResult {
    SearchResult {
        id: ContentId::Book(book.id),
        title: book.title,
        year: book.release_year,
        overview: book.description,
        poster: book.image.and_then(cover),
        creators: creators(book.contributions),
    }
}

/// Returns the names of a Book's creators, once each, most important first.
fn creators(contributions: Vec<api::Contribution>) -> Vec<String> {
    let mut creators = Vec::with_capacity(contributions.len());
    for contribution in contributions {
        // Counts a contribution without a role, which Hardcover's schema allows, as an author's
        let is_creator = contribution
            .contribution
            .as_deref()
            .is_none_or(|role| CREATOR_ROLES.contains(&role));
        if is_creator && !creators.contains(&contribution.author.name) {
            creators.push(contribution.author.name);
        }
    }
    creators
}

/// Returns a Book's cover, in the one size Hardcover has, or None when it has none.
fn cover(cover: api::Cover) -> Option<Image> {
    let (Some(url), Some(width), Some(height)) = (cover.url, cover.width, cover.height) else {
        return None;
    };
    Image::new([ImageSource { url, width, height }])
}
