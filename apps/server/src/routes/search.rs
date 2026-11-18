//! Content search, with how the API takes it.

use std::num::NonZeroU32;

use axum::extract::State;
use serde::Deserialize;
use utoipa::IntoParams;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    AppState,
    domain::{
        accounts::CurrentUser,
        contents::{self, MetadataProviders, SearchResults},
    },
    error::ApiError,
    routes::{Json, Query},
};

pub(super) fn routes() -> OpenApiRouter<AppState> {
    OpenApiRouter::new().routes(routes!(search))
}

/// Returns a page of the Movies and TV Shows whose title matches the query, most relevant first,
/// with their texts in the signed-in User's language.
#[utoipa::path(
    get,
    path = "/search",
    params(SearchParams),
    responses((status = OK, body = SearchResults)),
    security(("session_cookie" = []), ("session_token" = [])),
)]
async fn search(
    State(providers): State<MetadataProviders>,
    current_user: CurrentUser,
    Query(params): Query<SearchParams>,
) -> Result<Json<SearchResults>, ApiError> {
    let page = params.page.unwrap_or(NonZeroU32::MIN);
    let results = contents::search(
        &providers,
        &params.query,
        page,
        current_user.preferences.locale,
    )
    .await?;
    Ok(Json(results))
}

/// A search, and the page of its results to return.
#[derive(Deserialize, IntoParams)]
#[into_params(parameter_in = Query)]
struct SearchParams {
    /// The words to look for in titles. A blank query matches nothing
    query: String,
    /// The page to return, from 1, the default: the previous page's `next_page`
    #[param(value_type = Option<u32>, minimum = 1)]
    page: Option<NonZeroU32>,
}
