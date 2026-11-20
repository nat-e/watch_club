//! A fake sportarr.net, which answers what each test mounts on its `server`, such as the real
//! sportarr.net's answers in `fixtures/sportarr/`.

use std::{fs, path::Path};

use serde_json::Value;
use watch_club::domain::contents::{MetadataProviders, Sportarr};
use wiremock::{
    Mock, MockServer, ResponseTemplate,
    matchers::{method, path},
};

/// A sportarr.net that answers each request with what a mock on its `server` sets, and with a 404
/// when none matches.
pub struct FakeSportarr {
    pub server: MockServer,
}

impl FakeSportarr {
    pub async fn start() -> Self {
        Self {
            server: MockServer::start().await,
        }
    }

    /// Answers the GETs of `url_path`, percent-encoded, with `body`, such as a `fixture`.
    pub async fn answer(&self, url_path: &str, body: Value) {
        Mock::given(method("GET"))
            .and(path(url_path))
            .respond_with(ResponseTemplate::new(200).set_body_json(body))
            .mount(&self.server)
            .await;
    }

    /// Returns a client of this sportarr.net.
    pub fn client(&self) -> Sportarr {
        Sportarr::with_base_url(&super::http_client(), self.server.uri().parse().unwrap())
    }

    /// Returns the Metadata Providers of an instance that finds Sports Events in this sportarr.net,
    /// and calls other Metadata Providers that nothing answers.
    pub fn metadata_providers(&self) -> MetadataProviders {
        MetadataProviders {
            sportarr: self.client(),
            ..super::unreachable_metadata_providers()
        }
    }
}

/// Returns a client of a sportarr.net that nothing answers, for the tests that don't call it.
pub fn unreachable() -> Sportarr {
    Sportarr::with_base_url(&super::http_client(), "http://127.0.0.1:1".parse().unwrap())
}

/// Returns a real answer of sportarr.net, from `fixtures/sportarr/{name}.json`.
pub fn fixture(name: &str) -> Value {
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests/integration/fixtures/sportarr")
        .join(format!("{name}.json"));
    serde_json::from_str(&fs::read_to_string(path).unwrap()).unwrap()
}
