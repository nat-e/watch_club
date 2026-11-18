//! Hardcover's GraphQL API: the queries WatchClub sends, and the parts of their answers it reads.

use std::num::NonZeroU32;

use anyhow::{Context, bail};
use serde::{Deserialize, Deserializer, Serialize, de::DeserializeOwned};

use super::HardcoverId;
use crate::api_client::ApiClient;

/// The route of Hardcover's GraphQL API, which takes every query
const GRAPHQL_ROUTE: &str = "/graphql";

/// Searches the Books whose title, ISBNs, series, authors or other titles match `$query`. It ranks
/// them in three groups, from the best text matches, and the most read first within each.
///
/// Hardcover's default puts the best text matches first, and weighs titles above authors: a search
/// for an author lists the summaries with their name in the title before their books. Ranking by
/// popularity alone lifts popular Books that barely match, such as a translation's title with
/// "d'une" for "dune", so the other titles weigh least
pub(super) const SEARCH_BOOKS: &str = r#"
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
}"#;

/// Looks up the Book with the ID `$id`
pub(super) const BOOK: &str = r"
query Book($id: Int!) {
  books_by_pk(id: $id) {
    title
  }
}";

/// Sends a GraphQL query with these variables, and returns the data it answers.
///
/// Hardcover answers a query it can't run with `errors` rather than an HTTP error: they fail the
/// query too.
pub(super) async fn query<T: DeserializeOwned>(
    api: &ApiClient,
    query: &'static str,
    variables: impl Serialize,
) -> anyhow::Result<T> {
    let request = GraphQlRequest { query, variables };
    let response: GraphQlResponse<T> = api.post(GRAPHQL_ROUTE, &request).await?;

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

#[derive(Serialize)]
struct GraphQlRequest<V> {
    query: &'static str,
    variables: V,
}

#[derive(Deserialize)]
struct GraphQlResponse<T> {
    data: Option<T>,
    #[serde(default)]
    errors: Vec<GraphQlError>,
}

#[derive(Deserialize)]
struct GraphQlError {
    message: String,
}

/// The variables of `SEARCH_BOOKS`.
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct SearchBooksVariables<'a> {
    pub(super) query: &'a str,
    pub(super) page: NonZeroU32,
    pub(super) per_page: u32,
}

/// The data of `SEARCH_BOOKS`.
#[derive(Debug, Deserialize)]
pub(super) struct SearchBooks {
    pub(super) search: Search,
}

#[derive(Debug, Deserialize)]
pub(super) struct Search {
    /// The answer of Typesense, the search engine Hardcover uses
    pub(super) results: SearchPage,
}

/// A page of the Books that match a search, in Typesense's terms.
#[derive(Debug, Deserialize)]
pub(super) struct SearchPage {
    /// The number of Books that match, on every page
    pub(super) found: u32,
    pub(super) hits: Vec<SearchHit>,
}

#[derive(Debug, Deserialize)]
pub(super) struct SearchHit {
    pub(super) document: BookDocument,
}

/// A Book in search results.
#[derive(Debug, Deserialize)]
pub(super) struct BookDocument {
    /// Its ID, which Typesense sends as text
    #[serde(deserialize_with = "id_text")]
    pub(super) id: HardcoverId,
    pub(super) title: String,
    pub(super) release_year: Option<i16>,
    #[serde(default, deserialize_with = "optional_text")]
    pub(super) description: Option<String>,
    /// Its cover, whose fields are all null when it has none
    pub(super) image: Option<Cover>,
    /// The people credited for it, most important first
    #[serde(default)]
    pub(super) contributions: Vec<Contribution>,
}

/// A Book's cover.
#[derive(Debug, Deserialize)]
pub(super) struct Cover {
    pub(super) url: Option<String>,
    pub(super) width: Option<u32>,
    pub(super) height: Option<u32>,
}

/// A person credited for a Book, with their role.
#[derive(Debug, Deserialize)]
pub(super) struct Contribution {
    pub(super) author: Contributor,
    /// Their role, such as `Author`, `Illustrator` or `Translator`
    pub(super) contribution: Option<String>,
}

#[derive(Debug, Deserialize)]
pub(super) struct Contributor {
    pub(super) name: String,
}

/// The variables of `BOOK`.
#[derive(Serialize)]
pub(super) struct BookVariables {
    pub(super) id: HardcoverId,
}

/// The data of `BOOK`.
#[derive(Debug, Deserialize)]
pub(super) struct BookData {
    /// The Book, or None when Hardcover has no Book with this ID
    pub(super) books_by_pk: Option<Book>,
}

/// A Book's details.
#[derive(Debug, Deserialize)]
pub(super) struct Book {
    pub(super) title: String,
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
