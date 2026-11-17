//! The OpenAPI document of the API, which `packages/api` generates its client from.

use utoipa::{
    OpenApi,
    openapi::{
        self, Content, ObjectBuilder, PathItem, Schema, Type,
        path::Operation,
        security::{
            ApiKey, ApiKeyValue, Http, HttpAuthScheme, SecurityRequirement, SecurityScheme,
        },
    },
};

use crate::{auth::SESSION_COOKIE, error::ApiErrorKind};

#[derive(OpenApi)]
#[openapi(info(title = "WatchClub"))]
struct Description;

/// Returns the OpenAPI document of the API. Each endpoint describes itself with
/// `#[utoipa::path]`, and this adds what they share.
pub fn document() -> openapi::OpenApi {
    let mut document = Description::openapi().merge_from(crate::app().into_openapi());
    add_security_schemes(&mut document);
    add_error_responses(&mut document);
    document
}

/// Adds both ways of signing requests in, for the endpoints that list them in `security`.
fn add_security_schemes(document: &mut openapi::OpenApi) {
    let components = document.components.get_or_insert_default();
    components.add_security_scheme(
        "session_cookie",
        SecurityScheme::ApiKey(ApiKey::Cookie(ApiKeyValue::new(SESSION_COOKIE))),
    );
    components.add_security_scheme(
        "session_token",
        SecurityScheme::Http(Http::new(HttpAuthScheme::Bearer)),
    );
}

/// Adds the responses of `ApiError` to the endpoints that can send them.
///
/// A 400 goes to those that take a body, a 401 to those that need a session, and a 500 to all of
/// them, so that each `#[utoipa::path]` lists only the failures specific to its endpoint.
fn add_error_responses(document: &mut openapi::OpenApi) {
    for item in document.paths.paths.values_mut() {
        for operation in operations(item) {
            // Unless one of its requirements is the empty one, which makes the session optional
            let needs_session = operation.security.as_ref().is_some_and(|requirements| {
                !requirements.is_empty() && !requirements.contains(&SecurityRequirement::default())
            });
            let kinds = [
                (
                    operation.request_body.is_some(),
                    ApiErrorKind::InvalidRequest,
                ),
                (needs_session, ApiErrorKind::Unauthorized),
                (true, ApiErrorKind::Internal),
            ];
            for (sends, kind) in kinds {
                if sends {
                    operation
                        .responses
                        .responses
                        .entry(kind.status().as_str().to_owned())
                        .or_insert_with(|| error_response(kind).into());
                }
            }
        }
    }
}

/// Returns the OpenAPI response of an `ApiError` of this kind: its code, and the message.
fn error_response(kind: ApiErrorKind) -> openapi::Response {
    let description = match kind {
        ApiErrorKind::InvalidRequest => "The request was malformed or invalid.",
        ApiErrorKind::Unauthorized => "The request was not authorized.",
        ApiErrorKind::Internal => "Something went wrong. Try again later.",
    };
    let message = ObjectBuilder::new()
        .schema_type(Type::String)
        .description(Some(
            "The failure in English, for developers rather than users",
        ));
    let body: Schema = ObjectBuilder::new()
        .property(
            "code",
            ObjectBuilder::new()
                .schema_type(Type::String)
                .enum_values(Some([kind.code()])),
        )
        .required("code")
        .property("message", message)
        .required("message")
        .into();
    openapi::Response::builder()
        .description(description)
        .content("application/json", Content::new(Some(body)))
        .build()
}

fn operations(item: &mut PathItem) -> impl Iterator<Item = &mut Operation> {
    let PathItem {
        get,
        put,
        post,
        delete,
        options,
        head,
        patch,
        trace,
        query,
        additional_operations,
        ..
    } = item;
    [get, put, post, delete, options, head, patch, trace, query]
        .into_iter()
        .flatten()
        .chain(additional_operations.values_mut())
}
