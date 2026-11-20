//! A fake TMDB, which answers what each test mounts on its `server`, such as the real TMDB's answers
//! in `fixtures/tmdb/`.

use std::{fs, path::Path};

use secrecy::SecretString;
use serde_json::Value;
use watch_club::domain::{
    accounts::preferences::Locale,
    contents::{MetadataProviders, Tmdb},
};
use wiremock::{
    Mock, MockServer, ResponseTemplate,
    matchers::{method, path, query_param},
};

/// The API Read Access Token the clients of a fake TMDB send
pub const TOKEN: &str = "tmdb-token";

/// The TMDB ID of the Movie in `fixtures/tmdb/movie_details.json`, Amélie, whose original language
/// is French
pub const MOVIE_ID: u32 = 194;

/// The TMDB ID of the TV Show in `fixtures/tmdb/tv_details.json`, Chernobyl, which has one season
/// of 5 TV Show Episodes
pub const TV_SHOW_ID: u32 = 87_108;

/// A TMDB that answers each request with what a mock on its `server` sets, and with a 404 when none
/// matches.
pub struct FakeTmdb {
    pub server: MockServer,
}

impl FakeTmdb {
    pub async fn start() -> Self {
        Self {
            server: MockServer::start().await,
        }
    }

    /// Answers the GETs of `url_path` with `body`, such as a `fixture`.
    pub async fn answer(&self, url_path: &str, body: Value) {
        Mock::given(method("GET"))
            .and(path(url_path))
            .respond_with(ResponseTemplate::new(200).set_body_json(body))
            .mount(&self.server)
            .await;
    }

    /// Answers the GETs of `url_path` in the Locale's language with `body`.
    pub async fn answer_in(&self, url_path: &str, locale: Locale, body: Value) {
        Mock::given(method("GET"))
            .and(path(url_path))
            .and(query_param("language", locale.language_tag()))
            .respond_with(ResponseTemplate::new(200).set_body_json(body))
            .mount(&self.server)
            .await;
    }

    /// Answers the requests for the Movie and the TV Show of the fixtures, `MOVIE_ID` and
    /// `TV_SHOW_ID`, as the real TMDB did.
    pub async fn answer_fixtures(&self) {
        self.answer(&format!("/movie/{MOVIE_ID}"), fixture("movie_details"))
            .await;
        let tv_show_path = format!("/tv/{TV_SHOW_ID}");
        self.answer_in(&tv_show_path, Locale::EnUs, fixture("tv_details"))
            .await;
        self.answer_in(&tv_show_path, Locale::FrFr, fixture("tv_seasons_fr"))
            .await;
    }

    /// Returns a client of this TMDB.
    pub fn client(&self) -> Tmdb {
        Tmdb::with_base_url(
            &super::http_client(),
            &SecretString::from(TOKEN),
            self.server.uri().parse().unwrap(),
        )
        .unwrap()
    }

    /// Returns the Metadata Providers of an instance that finds Movies and TV Shows in this TMDB,
    /// and calls other Metadata Providers that nothing answers.
    pub fn metadata_providers(&self) -> MetadataProviders {
        MetadataProviders {
            tmdb: self.client(),
            ..super::unreachable_metadata_providers()
        }
    }
}

/// Returns a client of a TMDB that nothing answers, for the tests that don't call it.
pub fn unreachable() -> Tmdb {
    Tmdb::with_base_url(
        &super::http_client(),
        &SecretString::from(TOKEN),
        "http://127.0.0.1:1".parse().unwrap(),
    )
    .unwrap()
}

/// Returns a real answer of TMDB, from `fixtures/tmdb/{name}.json`.
pub fn fixture(name: &str) -> Value {
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests/integration/fixtures/tmdb")
        .join(format!("{name}.json"));
    serde_json::from_str(&fs::read_to_string(path).unwrap()).unwrap()
}
