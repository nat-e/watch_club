//! URLs, such as the addresses of the apps that WatchClub calls.

use reqwest::Url;

/// Returns the http or https URL that someone entered, trimmed and without its trailing `/`. None
/// when it isn't one.
pub fn tidy_http_url(text: &str) -> Option<String> {
    let text = text.trim().trim_end_matches('/');
    parse_http_url(text).map(|_| text.to_owned())
}

/// Returns the http or https URL that someone entered, as `tidy_http_url` tidies it. None when it
/// isn't one.
pub fn parse_http_url(text: &str) -> Option<Url> {
    let url = Url::parse(text.trim().trim_end_matches('/')).ok()?;
    matches!(url.scheme(), "http" | "https").then_some(url)
}
