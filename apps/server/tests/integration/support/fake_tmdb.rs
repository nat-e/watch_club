//! A fake TMDB, which answers what each test mounts on its `server`, such as the real TMDB's answers
//! in `fixtures/tmdb/`.

use std::{fs, path::Path};

use secrecy::SecretString;
use serde_json::Value;
use watch_club::domain::contents::{MetadataProviders, Tmdb};
use wiremock::{
    Mock, MockServer, ResponseTemplate,
    matchers::{method, path},
};

/// The API Read Access Token the clients of a fake TMDB send
pub const TOKEN: &str = "tmdb-token";

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

    /// Returns a client of this TMDB.
    pub fn client(&self) -> Tmdb {
        Tmdb::with_base_url(&SecretString::from(TOKEN), &self.server.uri()).unwrap()
    }

    /// Returns the Metadata Providers of an instance that finds Content in this TMDB.
    pub fn providers(&self) -> MetadataProviders {
        MetadataProviders {
            tmdb: self.client(),
        }
    }
}

/// Returns a client of a TMDB that nothing answers, for the tests that don't call it.
pub fn unreachable() -> Tmdb {
    Tmdb::with_base_url(&SecretString::from(TOKEN), "http://127.0.0.1:1").unwrap()
}

/// Returns a real answer of TMDB, from `fixtures/tmdb/{name}.json`.
pub fn fixture(name: &str) -> Value {
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests/integration/fixtures/tmdb")
        .join(format!("{name}.json"));
    serde_json::from_str(&fs::read_to_string(path).unwrap()).unwrap()
}
