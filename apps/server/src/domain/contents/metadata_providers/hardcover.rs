//! Hardcover: the Metadata Provider of Books, which WatchClub calls through its GraphQL API.

use std::{
    fmt::{self, Display, Formatter},
    num::{NonZeroU32, ParseIntError},
    str::FromStr,
};

use anyhow::{Context, bail};
use jiff::civil::Date;
use reqwest::Url;
use secrecy::{ExposeSecret, SecretString};
use serde::{Deserialize, Deserializer, Serialize, de::DeserializeOwned};
use serde_json::json;

use crate::{
    api_client::{ApiClient, ApiCredentials, HttpClient},
    domain::{
        InternalError,
        contents::{
            ContentMetadata, ContentTranslations, CreditKind, CreditMetadata, ExternalContentId,
            ExternalIds, Image, ImageSource, LookUpError, SearchResult, SearchResults,
            Translations,
        },
    },
};

/// The address of Hardcover's API
const BASE_URL: &str = "https://api.hardcover.app/v1";

/// The route of Hardcover's GraphQL API, which takes every query
const GRAPHQL_ROUTE: &str = "/graphql";

/// The number of Books on a page of search results
const PAGE_SIZE: u32 = 20;

/// The roles of the people a Book credits that make them its creators, leaving out roles such as
/// translator or narrator. Hardcover's roles are free text, which some Books write otherwise
const CREATOR_ROLES: [&str; 3] = ["Author", "Illustrator", "Illustrations"];

/// The ID of a Book at Hardcover, a GraphQL `Int`: a signed 32-bit number.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
pub struct HardcoverId(i32);

impl HardcoverId {
    pub const fn new(id: i32) -> Self {
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
    pub fn new(http_client: &HttpClient, token: &SecretString) -> anyhow::Result<Self> {
        let base_url = Url::parse(BASE_URL).expect("BASE_URL is a URL");
        Self::with_base_url(http_client, token, base_url)
    }

    /// Returns a Hardcover at another address, such as a fake one in tests.
    pub fn with_base_url(
        http_client: &HttpClient,
        token: &SecretString,
        base_url: Url,
    ) -> anyhow::Result<Self> {
        // Hardcover shows the token after `Bearer `, so hosts may copy both
        let token = token.expose_secret();
        let token = token.strip_prefix("Bearer ").unwrap_or(token).trim();
        let credentials = ApiCredentials::bearer_token(&SecretString::from(token))
            .context("Hardcover's API token is invalid")?;

        Ok(Self {
            api: ApiClient::new(http_client, base_url, credentials),
        })
    }

    /// Returns a page of the Books whose title, series, authors or ISBN match the query, the best
    /// matches first, and the most read on Hardcover among similar matches.
    pub async fn search(
        &self,
        query: &str,
        page: NonZeroU32,
    ) -> Result<SearchResults, InternalError> {
        // The closest matches first, and the most read first among equally close ones. Authors weigh
        // as much as titles, so that searching an author finds their books before the summaries
        // named after them. Other titles, such as translations, weigh least, so that popular Books
        // that barely match stay behind
        let data: SearchBooksData = self
            .query(
                r#"
                query SearchBooks($query: String!, $page: Int!, $perPage: Int!) {
                  search(
                    query: $query
                    query_type: "book"
                    fields: "title,isbns,series_names,author_names,alternative_titles"
                    weights: "5,5,3,5,1"
                    sort: "_text_match(buckets: 3):desc,users_count:desc"
                    page: $page
                    per_page: $perPage
                  ) {
                    results
                  }
                }"#,
                json!({"query": query, "page": page, "perPage": PAGE_SIZE}),
            )
            .await?;
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

    /// Returns the Book with this ID. Hardcover doesn't say which language its texts are in, so
    /// they're its original ones. A Book has no Media yet.
    pub async fn fetch_book(&self, id: HardcoverId) -> Result<ContentMetadata, LookUpError> {
        let data: BookData = self
            .query(
                r"
                query Book($id: Int!) {
                  books_by_pk(id: $id) {
                    title
                    description
                    release_date
                    image {
                      url
                      width
                      height
                    }
                    contributions {
                      contribution
                      author {
                        id
                        name
                        image {
                          url
                          width
                          height
                        }
                      }
                    }
                  }
                }",
                json!({"id": id}),
            )
            .await?;
        let book = data.books_by_pk.ok_or(LookUpError::NotFound)?;

        Ok(ContentMetadata {
            id: ExternalContentId::Book(id),
            external_ids: ExternalIds::default(),
            original_title: book.title,
            original_language: None,
            origin_country: None,
            release_date: book.release_date,
            genres: Vec::new(),
            rating: None,
            backdrop: None,
            texts: ContentTranslations {
                overviews: Translations::original(book.description),
                posters: Translations::original(book.image.and_then(cover)),
                ..ContentTranslations::default()
            },
            credits: credits(book.contributions),
            media: Vec::new(),
        })
    }

    /// Sends a GraphQL query with these variables, and returns the data it answers.
    ///
    /// Hardcover answers a query it can't run with `errors` rather than an HTTP error: they fail the
    /// query too.
    async fn query<T: DeserializeOwned>(
        &self,
        query: &'static str,
        variables: serde_json::Value,
    ) -> anyhow::Result<T> {
        let request = GraphQlRequest { query, variables };
        let response: GraphQlResponse<T> = self.api.post(GRAPHQL_ROUTE, &request).await?;

        if !response.errors.is_empty() {
            let messages: Vec<_> = response
                .errors
                .into_iter()
                .map(|error| error.message)
                .collect();
            bail!("Hardcover failed a query: {}", messages.join("; "));
        }
        response
            .data
            .context("Hardcover answered a query without data or errors")
    }
}

/// Returns the search result a Book of Hardcover's search is.
fn search_result(book: BookDocument) -> SearchResult {
    SearchResult {
        external_content_id: ExternalContentId::Book(book.id),
        title: book.title,
        date: book.release_date,
        overview: book.description,
        poster: book.image.and_then(cover),
        creators: creators(book.contributions),
    }
}

/// Returns the names of a Book's creators, once each, most important first.
fn creators(contributions: Vec<Contribution>) -> Vec<String> {
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

/// Returns the credits of a Book's authors, illustrators and narrators, once each, most important
/// first, leaving out roles such as translator.
fn credits(contributions: Vec<BookContribution>) -> Vec<CreditMetadata> {
    let mut credits: Vec<CreditMetadata> = Vec::with_capacity(contributions.len());
    for contribution in contributions {
        // Counts a contribution without a role, which Hardcover's schema allows, as an author's
        let kind = match contribution.contribution.as_deref() {
            None | Some("Author") => CreditKind::Author,
            Some("Illustrator" | "Illustrations") => CreditKind::Illustrator,
            Some("Narrator") => CreditKind::Narrator,
            Some(_) => continue,
        };
        let author_id = Some(contribution.author.id.to_string());
        let is_listed = credits
            .iter()
            .any(|credit| credit.kind == kind && credit.external_ids.hardcover == author_id);
        if is_listed {
            continue;
        }

        credits.push(CreditMetadata {
            kind,
            name: contribution.author.name,
            character: None,
            photo: contribution.author.image.and_then(cover),
            external_ids: ExternalIds {
                hardcover: author_id,
                ..ExternalIds::default()
            },
        });
    }
    credits
}

/// Returns a Book's cover, or a person's photo, in the one size Hardcover has, or None when it has
/// none.
fn cover(cover: Cover) -> Option<Image> {
    let (Some(url), Some(width), Some(height)) = (cover.url, cover.width, cover.height) else {
        return None;
    };
    Image::new([ImageSource { url, width, height }])
}

/// A GraphQL query and its variables, as Hardcover takes them.
#[derive(Serialize)]
struct GraphQlRequest {
    query: &'static str,
    variables: serde_json::Value,
}

/// Hardcover's answer to a GraphQL query: its data, or the errors that kept it from running.
#[derive(Deserialize)]
struct GraphQlResponse<T> {
    data: Option<T>,
    #[serde(default)]
    errors: Vec<GraphQlError>,
}

/// An error that kept a GraphQL query from running.
#[derive(Deserialize)]
struct GraphQlError {
    message: String,
}

/// The data of the search query.
#[derive(Debug, Deserialize)]
struct SearchBooksData {
    search: Search,
}

/// The results of a search.
#[derive(Debug, Deserialize)]
struct Search {
    /// The answer of Typesense, the search engine Hardcover uses
    results: SearchPage,
}

/// A page of the Books that match a search, in Typesense's terms.
#[derive(Debug, Deserialize)]
struct SearchPage {
    /// The number of Books that match, on every page
    found: u32,
    hits: Vec<SearchHit>,
}

/// A Book that matches a search.
#[derive(Debug, Deserialize)]
struct SearchHit {
    document: BookDocument,
}

/// A Book in search results.
#[derive(Debug, Deserialize)]
struct BookDocument {
    /// Its ID, which Typesense sends as text
    #[serde(deserialize_with = "id_text")]
    id: HardcoverId,
    title: String,
    /// The day it came out, or January 1st of its year when Hardcover doesn't know the day
    #[serde(default, deserialize_with = "optional_date")]
    release_date: Option<Date>,
    #[serde(default, deserialize_with = "optional_text")]
    description: Option<String>,
    /// Its cover, whose fields are all null when it has none
    image: Option<Cover>,
    /// The people credited for it, most important first
    #[serde(default)]
    contributions: Vec<Contribution>,
}

/// A Book's cover.
#[derive(Debug, Deserialize)]
struct Cover {
    url: Option<String>,
    width: Option<u32>,
    height: Option<u32>,
}

/// A person credited for a Book, with their role.
#[derive(Debug, Deserialize)]
struct Contribution {
    author: Contributor,
    /// Their role, such as `Author`, `Illustrator` or `Translator`
    contribution: Option<String>,
}

/// A person credited for a Book.
#[derive(Debug, Deserialize)]
struct Contributor {
    name: String,
}

/// The data of the query of a Book.
#[derive(Debug, Deserialize)]
struct BookData {
    /// The Book, or None when Hardcover has no Book with this ID
    books_by_pk: Option<Book>,
}

/// A Book's details.
#[derive(Debug, Deserialize)]
struct Book {
    title: String,
    #[serde(default, deserialize_with = "optional_text")]
    description: Option<String>,
    /// The day it came out, or January 1st of its year when Hardcover doesn't know the day
    #[serde(default, deserialize_with = "optional_date")]
    release_date: Option<Date>,
    image: Option<Cover>,
    /// The people credited for it, most important first
    #[serde(default)]
    contributions: Vec<BookContribution>,
}

/// A person credited for a Book, with their role, as a Book's details have them.
#[derive(Debug, Deserialize)]
struct BookContribution {
    author: BookContributor,
    /// Their role, such as `Author`, `Illustrator` or `Translator`
    contribution: Option<String>,
}

/// A person credited for a Book, as a Book's details have them.
#[derive(Debug, Deserialize)]
struct BookContributor {
    id: i32,
    name: String,
    image: Option<Cover>,
}

/// Reads an ID that Typesense sends as text, such as `"427578"`.
fn id_text<'de, D: Deserializer<'de>>(deserializer: D) -> Result<HardcoverId, D::Error> {
    let text = String::deserialize(deserializer)?;
    text.parse().map_err(serde::de::Error::custom)
}

/// Reads a text that Hardcover sends blank, or null, when it has none.
fn optional_text<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<String>, D::Error> {
    let text = Option::<String>::deserialize(deserializer)?;
    Ok(text
        .map(|text| text.trim().to_owned())
        .filter(|text| !text.is_empty()))
}

/// Reads a date that Hardcover sends as `YYYY-MM-DD`, or blank, or null, when it has none.
fn optional_date<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<Date>, D::Error> {
    optional_text(deserializer)?
        .map(|date| date.parse().map_err(serde::de::Error::custom))
        .transpose()
}
