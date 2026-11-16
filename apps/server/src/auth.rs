//! Finds the signed-in User of an API request from its session token. Browsers send the token in
//! the `session` cookie, which this module sets and clears; the mobile apps send it in an
//! `Authorization: Bearer` header.

use std::{convert::Infallible, future};

use axum::{
    RequestPartsExt,
    extract::{FromRef, FromRequestParts, OptionalFromRequestParts},
    http::request::Parts,
};
use axum_extra::{
    extract::{
        CookieJar,
        cookie::{Cookie, SameSite},
    },
    headers::{Authorization, HeaderMapExt, authorization::Bearer},
};
use sqlx::PgPool;

use crate::{
    domain::accounts::{self, SESSION_LIFETIME, SessionToken, User},
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

/// The signed-in User, for the endpoints that need one. Requests without a valid session fail
/// with a 401.
pub(crate) struct CurrentUser(pub User);

impl<S: Send + Sync> FromRequestParts<S> for CurrentUser
where
    PgPool: FromRef<S>,
{
    type Rejection = ApiError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, ApiError> {
        let Ok(Some(token)) = parts.extract::<Option<SessionToken>>().await else {
            return Err(ApiError::Unauthorized);
        };
        let user = accounts::session_user(&PgPool::from_ref(state), &token)
            .await?
            .ok_or(ApiError::Unauthorized)?;
        Ok(Self(user))
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
