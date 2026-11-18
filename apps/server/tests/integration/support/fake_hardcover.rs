//! A fake Hardcover, which answers what each test mounts on its `server`, such as the real
//! Hardcover's answers in `fixtures/hardcover/`.

use std::{fs, path::Path};

use secrecy::SecretString;
use serde_json::Value;
use watch_club::domain::contents::{Hardcover, MetadataProviders};
use wiremock::{
    Mock, MockServer, ResponseTemplate,
    matchers::{body_string_contains, method, path},
};

/// The API token the clients of a fake Hardcover send
pub const TOKEN: &str = "hardcover-token";

/// A Hardcover that answers each request with what a mock on its `server` sets, and with a 404
/// when none matches.
pub struct FakeHardcover {
    pub server: MockServer,
}

impl FakeHardcover {
    pub async fn start() -> Self {
        Self {
            server: MockServer::start().await,
        }
    }

    /// Answers the GraphQL queries named `operation`, such as `SearchBooks`, with `body`, such as a
    /// `fixture`.
    pub async fn answer(&self, operation: &str, body: Value) {
        Mock::given(method("POST"))
            .and(path("/graphql"))
            .and(body_string_contains(format!("query {operation}(")))
            .respond_with(ResponseTemplate::new(200).set_body_json(body))
            .mount(&self.server)
            .await;
    }

    /// Returns a client of this Hardcover.
    pub fn client(&self) -> Hardcover {
        Hardcover::with_base_url(&SecretString::from(TOKEN), &self.server.uri()).unwrap()
    }

    /// Returns the Metadata Providers of an instance that finds Books in this Hardcover, and calls
    /// a TMDB that nothing answers.
    pub fn metadata_providers(&self) -> MetadataProviders {
        MetadataProviders {
            hardcover: self.client(),
            ..super::unreachable_metadata_providers()
        }
    }
}

/// Returns a client of a Hardcover that nothing answers, for the tests that don't call it.
pub fn unreachable() -> Hardcover {
    Hardcover::with_base_url(&SecretString::from(TOKEN), "http://127.0.0.1:1").unwrap()
}

/// Returns a real answer of Hardcover, from `fixtures/hardcover/{name}.json`.
pub fn fixture(name: &str) -> Value {
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests/integration/fixtures/hardcover")
        .join(format!("{name}.json"));
    serde_json::from_str(&fs::read_to_string(path).unwrap()).unwrap()
}
