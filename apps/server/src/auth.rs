//! Finds the signed-in User of an API request from its session token. Browsers send the token in
//! the `session` cookie, which this module sets and clears; the mobile apps send it in an
//! `Authorization: Bearer` header.

use std::{convert::Infallible, future};

use axum::{
    RequestPartsExt,
    extract::{FromRef, FromRequestParts, OptionalFromRequestParts},
    http::request::Parts,
    response::{IntoResponse, Response},
};
use axum_extra::{
    extract::{
        CookieJar,
        cookie::{Cookie, SameSite},
    },
    headers::{Authorization, HeaderMapExt, authorization::Bearer},
};

use crate::{
    db::Pool,
    domain::accounts::{self, CurrentUser, SESSION_LIFETIME, SessionToken},
    error::ApiError,
};

pub(crate) const SESSION_COOKIE: &str = "session";

/// Lets endpoints take an `Option<SessionToken>` argument: the request's session token, or None
/// when it has none. For endpoints that need the token rather than the User, such as sign-out.
impl<S: Send + Sync> OptionalFromRequestParts<S> for SessionToken {
    type Rejection = Infallible;

    fn from_request_parts(
        parts: &mut Parts,
        _: &S,
    ) -> impl Future<Output = Result<Option<Self>, Infallible>> + Send {
        let token = match parts.headers.typed_get::<Authorization<Bearer>>() {
            Some(authorization) => Self::decode(authorization.token()),
            None => CookieJar::from_headers(&parts.headers)
                .get(SESSION_COOKIE)
                .and_then(|cookie| Self::decode(cookie.value())),
        };
        future::ready(Ok(token))
    }
}

/// Lets endpoints take a `CurrentUser` argument: the signed-in User, for the endpoints that need
/// one. Requests without a valid session fail with a 401.
impl<S: Send + Sync> FromRequestParts<S> for CurrentUser
where
    Pool: FromRef<S>,
{
    // The response of an `ApiError`, which is private to the crate unlike `CurrentUser`
    type Rejection = Response;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Response> {
        let Ok(Some(token)) = parts.extract::<Option<SessionToken>>().await else {
            return Err(ApiError::Unauthorized.into_response());
        };
        let current_user = accounts::session_user(&Pool::from_ref(state), &token)
            .await
            .map_err(|error| ApiError::from(error).into_response())?;
        current_user.ok_or_else(|| ApiError::Unauthorized.into_response())
    }
}

/// Proof that the Instance Administrator signed the request: endpoints only they can call take it
/// as an argument. Requests without a valid session fail with a 401, and other Users' with a 403.
/// Their `security` names the `instance_administrator` role, so that their description lists the
/// 403.
pub(crate) struct InstanceAdministrator;

impl<S: Send + Sync> FromRequestParts<S> for InstanceAdministrator
where
    Pool: FromRef<S>,
{
    type Rejection = Response;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Response> {
        let current_user = CurrentUser::from_request_parts(parts, state).await?;
        if !current_user.is_instance_administrator {
            return Err(ApiError::Forbidden.into_response());
        }
        Ok(Self)
    }
}

/// The browser's session cookie, which keeps it signed in. Scripts can't read it, and other
/// sites can't make the browser send it.
pub(crate) struct SessionCookie {
    jar: CookieJar,
    secure: bool,
}

impl<S: Send + Sync> FromRequestParts<S> for SessionCookie {
    type Rejection = Infallible;

    fn from_request_parts(
        parts: &mut Parts,
        _: &S,
    ) -> impl Future<Output = Result<Self, Infallible>> + Send {
        // Behind a reverse proxy that serves HTTPS. Clients can fake the header, but it only
        // changes their own cookie
        let secure = parts
            .headers
            .get("x-forwarded-proto")
            .is_some_and(|proto| proto == "https");
        future::ready(Ok(Self {
            jar: CookieJar::from_headers(&parts.headers),
            secure,
        }))
    }
}

impl SessionCookie {
    /// Keeps the browser signed in with the token for the session's lifetime.
    pub(crate) fn set(self, token: &SessionToken) -> CookieJar {
        let max_age = time::Duration::seconds(SESSION_LIFETIME.as_secs());
        let cookie = Cookie::build((SESSION_COOKIE, token.encode()))
            .path("/")
            .http_only(true)
            .same_site(SameSite::Strict)
            .secure(self.secure)
            .max_age(max_age);
        self.jar.add(cookie)
    }

    pub(crate) fn remove(self) -> CookieJar {
        self.jar.remove(Cookie::build(SESSION_COOKIE).path("/"))
    }
}
