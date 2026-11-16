//! The web app, on every path outside the API, from the files that release builds embed.

use axum::{
    http::{
        StatusCode, Uri,
        header::{CACHE_CONTROL, CONTENT_TYPE},
    },
    response::{IntoResponse, Response},
};
use rust_embed::{EmbeddedFile, RustEmbed};

use crate::routes;

#[derive(RustEmbed)]
#[folder = "../web/dist"]
// The web app's dev server serves it during development, so the server builds without it
#[allow_missing = true]
struct Files;

/// Returns the web app's file at the URI's path, or else its page, which shows the right screen
/// for the path itself. Unknown API paths aren't found, rather than showing the web app.
pub(crate) async fn serve(uri: Uri) -> Response {
    if uri
        .path()
        .strip_prefix(routes::PATH)
        .is_some_and(|rest| rest.is_empty() || rest.starts_with('/'))
    {
        return StatusCode::NOT_FOUND.into_response();
    }
    let path = uri.path().trim_start_matches('/');
    if let Some(file) = Files::get(path) {
        return respond(path, file);
    }
    match Files::get("index.html") {
        Some(page) => respond("index.html", page),
        None => (
            StatusCode::NOT_FOUND,
            "The web app isn't built: open the dev server instead, or run `pnpm build`",
        )
            .into_response(),
    }
}

fn respond(path: &str, file: EmbeddedFile) -> Response {
    // Vite names the files in `assets/` after their content, so they never change
    let cache_control = if path.starts_with("assets/") {
        "public, max-age=31536000, immutable"
    } else {
        "no-cache"
    };
    let headers = [
        (CONTENT_TYPE, file.metadata.mimetype().to_owned()),
        (CACHE_CONTROL, cache_control.to_owned()),
    ];
    (headers, file.data).into_response()
}
