//! A client for TMDB, The Movie Database, where WatchClub finds Movies and TV Shows, and their
//! details in each Locale's language: titles, overviews, images, credits and episodes.

mod details;
mod search;

use std::num::NonZeroU32;

use anyhow::{Context, anyhow};
use reqwest::{
    StatusCode, Url,
    header::{AUTHORIZATION, HeaderMap, HeaderValue},
};
use reqwest_middleware::ClientWithMiddleware;
use reqwest_tracing::OtelName;
use secrecy::{ExposeSecret, SecretString};
use serde::{Deserialize, Deserializer, de::DeserializeOwned};

pub use self::{
    details::{
        CastMember, Collection, Credits, CrewMember, Episode, ExternalIds, Genre, Image, Images,
        MovieDetails, MovieTranslationData, ProductionCompany, ProductionCountry, Season,
        SeasonDetails, SpokenLanguage, Translation, TvShowDetails, TvShowTranslationData, Video,
        Videos,
    },
    search::{
        FindResults, KnownFor, MovieSearchResult, MultiSearchResult, PersonSearchResult,
        SearchPage, TvEpisodeResult, TvShowSearchResult,
    },
};
use super::http;
use crate::domain::{InternalError, accounts::Locale};

/// The address of TMDB's API
const BASE_URL: &str = "https://api.themoviedb.org/3";

/// The languages of the images that details include: those of every Locale, and `null` for those
/// without text. TMDB otherwise only includes the images in the details' language.
const IMAGE_LANGUAGES: &str = "en,fr,null";

/// A client for TMDB's API, signed in with the API Read Access Token of the instance. Clones share
/// their connections.
#[derive(Clone, Debug)]
pub struct Client {
    http: ClientWithMiddleware,
    base_url: Url,
}

/// The failures of a call for something by its ID.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// TMDB has nothing with this ID
    #[error("TMDB has nothing with this ID")]
    NotFound,
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

impl From<Error> for InternalError {
    fn from(error: Error) -> Self {
        match error {
            Error::NotFound => anyhow!(error).into(),
            Error::Internal(error) => error.into(),
        }
    }
}

/// Another site's ID of a Movie, a TV Show or an episode, to find it on TMDB.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ExternalId {
    /// An IMDb ID, such as `tt0211915`
    Imdb(String),
    /// A TheTVDB ID
    Tvdb(u32),
}

impl Client {
    /// Returns a client that signs in with `token`, the instance's API Read Access Token.
    pub fn new(token: &SecretString) -> anyhow::Result<Self> {
        Self::with_base_url(token, BASE_URL)
    }

    /// Returns a client of a TMDB at another address, such as a fake one in tests.
    pub fn with_base_url(token: &SecretString, base_url: &str) -> anyhow::Result<Self> {
        let base_url = Url::parse(base_url).context("TMDB's address isn't a URL")?;
        anyhow::ensure!(
            !base_url.cannot_be_a_base(),
            "TMDB's address can't have paths"
        );
        let mut authorization = HeaderValue::try_from(format!("Bearer {}", token.expose_secret()))
            .context("the TMDB token can't go in a header")?;
        // Keeps it out of logs and debug output
        authorization.set_sensitive(true);
        let headers = HeaderMap::from_iter([(AUTHORIZATION, authorization)]);
        Ok(Self {
            http: http::client(headers)?,
            base_url,
        })
    }

    /// Returns a page of the Movies, TV Shows and people whose title or name matches the query,
    /// most relevant first, in the Locale's language. It leaves out adult content.
    pub async fn search_multi(
        &self,
        query: &str,
        page: NonZeroU32,
        locale: Locale,
    ) -> Result<SearchPage<MultiSearchResult>, InternalError> {
        let page = page.to_string();
        let params = search_params(query, &page, locale);
        Ok(self
            .get("/search/multi", &["search", "multi"], &params)
            .await?)
    }

    /// Returns a page of the Movies whose title matches the query, most relevant first, in the
    /// Locale's language, released in `year` if set. It leaves out adult content.
    pub async fn search_movies(
        &self,
        query: &str,
        year: Option<i16>,
        page: NonZeroU32,
        locale: Locale,
    ) -> Result<SearchPage<MovieSearchResult>, InternalError> {
        let page = page.to_string();
        let year = year.map(|year| year.to_string());
        let mut params = search_params(query, &page, locale);
        params.extend(year.as_deref().map(|year| ("primary_release_year", year)));
        Ok(self
            .get("/search/movie", &["search", "movie"], &params)
            .await?)
    }

    /// Returns a page of the TV Shows whose name matches the query, most relevant first, in the
    /// Locale's language, first aired in `year` if set. It leaves out adult content.
    pub async fn search_tv_shows(
        &self,
        query: &str,
        year: Option<i16>,
        page: NonZeroU32,
        locale: Locale,
    ) -> Result<SearchPage<TvShowSearchResult>, InternalError> {
        let page = page.to_string();
        let year = year.map(|year| year.to_string());
        let mut params = search_params(query, &page, locale);
        params.extend(year.as_deref().map(|year| ("first_air_date_year", year)));
        Ok(self.get("/search/tv", &["search", "tv"], &params).await?)
    }

    /// Returns the Movies, TV Shows and episodes that another site knows by this ID, in English.
    pub async fn find_by_external_id(&self, id: &ExternalId) -> Result<FindResults, InternalError> {
        let (id, source) = match id {
            ExternalId::Imdb(id) => (id.clone(), "imdb_id"),
            ExternalId::Tvdb(id) => (id.to_string(), "tvdb_id"),
        };
        Ok(self
            .get(
                "/find/{external_id}",
                &["find", &id],
                &[("external_source", source)],
            )
            .await?)
    }

    /// Returns the Movie's details in the Locale's language, with its translations, images, credits
    /// and videos.
    pub async fn movie_details(&self, id: u32, locale: Locale) -> Result<MovieDetails, Error> {
        self.get(
            "/movie/{id}",
            &["movie", &id.to_string()],
            &[
                ("language", locale.language_tag()),
                ("append_to_response", "translations,images,credits,videos"),
                ("include_image_language", IMAGE_LANGUAGES),
            ],
        )
        .await
    }

    /// Returns the TV Show's details in the Locale's language, with its seasons, translations,
    /// images, IDs on other sites, credits and videos.
    pub async fn tv_show_details(&self, id: u32, locale: Locale) -> Result<TvShowDetails, Error> {
        self.get(
            "/tv/{id}",
            &["tv", &id.to_string()],
            &[
                ("language", locale.language_tag()),
                (
                    "append_to_response",
                    "translations,images,external_ids,credits,videos",
                ),
                ("include_image_language", IMAGE_LANGUAGES),
            ],
        )
        .await
    }

    /// Returns a season of the TV Show in the Locale's language, with its episodes.
    pub async fn season_details(
        &self,
        tv_show_id: u32,
        season_number: u32,
        locale: Locale,
    ) -> Result<SeasonDetails, Error> {
        self.get(
            "/tv/{id}/season/{season_number}",
            &[
                "tv",
                &tv_show_id.to_string(),
                "season",
                &season_number.to_string(),
            ],
            &[("language", locale.language_tag())],
        )
        .await
    }

    /// Calls the API's `route` at the path of `segments`, which it escapes, and reads its JSON.
    async fn get<T: DeserializeOwned>(
        &self,
        route: &'static str,
        segments: &[&str],
        params: &[(&str, &str)],
    ) -> Result<T, Error> {
        let mut url = self.base_url.clone();
        url.path_segments_mut()
            .expect("`with_base_url` checked that the URL can have paths")
            .pop_if_empty()
            .extend(segments);
        let response = self
            .http
            .get(url)
            .query(params)
            .with_extension(OtelName(format!("GET {route}").into()))
            .send()
            .await
            .with_context(|| format!("failed to call TMDB's {route}"))?;
        let status = response.status();
        let body = response
            .bytes()
            .await
            .with_context(|| format!("failed to receive TMDB's answer to {route}"))?;
        if status == StatusCode::NOT_FOUND {
            return Err(Error::NotFound);
        }
        if !status.is_success() {
            // TMDB says what went wrong in its body
            let message = serde_json::from_slice::<ErrorBody>(&body)
                .map(|body| body.status_message)
                .unwrap_or_default();
            return Err(anyhow!("TMDB answered {route} with {status}: {message}").into());
        }
        let answer = serde_json::from_slice(&body)
            .with_context(|| format!("failed to read TMDB's answer to {route}"))?;
        Ok(answer)
    }
}

/// The parameters every search takes.
fn search_params<'a>(query: &'a str, page: &'a str, locale: Locale) -> Vec<(&'a str, &'a str)> {
    vec![
        ("query", query),
        ("page", page),
        ("include_adult", "false"),
        ("language", locale.language_tag()),
    ]
}

/// The body of TMDB's failures.
#[derive(Deserialize)]
struct ErrorBody {
    status_message: String,
}

/// Reads a text that TMDB sends empty, or null, when it has none.
fn optional_text<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<String>, D::Error> {
    let text = Option::<String>::deserialize(deserializer)?;
    Ok(text.filter(|text| !text.is_empty()))
}

/// Reads a date that TMDB sends as `YYYY-MM-DD`, or empty, or null, when it has none.
fn optional_date<'de, D: Deserializer<'de>>(
    deserializer: D,
) -> Result<Option<jiff::civil::Date>, D::Error> {
    optional_text(deserializer)?
        .map(|date| date.parse().map_err(serde::de::Error::custom))
        .transpose()
}
