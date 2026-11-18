//! Content search, with how the API takes it.

use std::num::NonZeroU32;

use axum::extract::State;
use serde::Deserialize;
use utoipa::{IntoParams, OpenApi};
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    ApiContext,
    domain::{
        accounts::CurrentUser,
        contents::{self, MetadataProviders, SearchResults, SearchScope},
    },
    error::ApiError,
    routes::{Json, Query},
};

pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::with_openapi(SearchSchemas::openapi()).routes(routes!(search))
}

/// The schemas that only the search's parameters use, such as `SearchScope`.
///
/// utoipa adds to the OpenAPI document the schemas that request bodies and responses use, but not
/// those of parameters: without this, the `scope` parameter refers to a schema the document lacks,
/// and the apps' client has no `SearchScope` type. Remove it once utoipa collects them:
/// <https://github.com/juhaku/utoipa/issues/1165>
#[derive(OpenApi)]
#[openapi(components(schemas(SearchScope)))]
struct SearchSchemas;

/// Returns a page of the Content of the scope that matches the query, most relevant first, with
/// their texts in the signed-in User's language when their Metadata Provider has them.
#[utoipa::path(
    get,
    path = "/search",
    params(SearchParams),
    responses((status = OK, body = SearchResults)),
    security(("session_cookie" = []), ("session_token" = [])),
)]
async fn search(
    State(metadata_providers): State<MetadataProviders>,
    current_user: CurrentUser,
    Query(params): Query<SearchParams>,
) -> Result<Json<SearchResults>, ApiError> {
    let page = params.page.unwrap_or(NonZeroU32::MIN);
    let locale = current_user.preferences.locale;
    let results = contents::search(
        &metadata_providers,
        &params.query,
        params.scope,
        page,
        locale,
    )
    .await?;
    Ok(Json(results))
}

/// A search, and the page of its results to return.
#[derive(Deserialize, IntoParams)]
#[into_params(parameter_in = Query)]
struct SearchParams {
    /// The words to look for, such as a title. A blank query matches nothing
    query: String,
    /// The Content Types to look for
    scope: SearchScope,
    /// The page to return, from 1, the default: the previous page's `next_page`
    #[param(value_type = Option<u32>, minimum = 1)]
    page: Option<NonZeroU32>,
}
