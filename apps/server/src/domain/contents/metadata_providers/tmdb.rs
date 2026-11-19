//! TMDB, The Movie Database: the Metadata Provider of Movies and TV Shows.
//!
//! The client, and what its modules share, such as the sizes of TMDB's images: `search` searches
//! TMDB, `details` reads a Movie's or a TV Show's details, `tv_show` a TV Show's Episodes, and
//! `credits` who made a Content and who's in it.

mod credits;
mod details;
mod search;
mod tv_show;

use std::{
    fmt::{self, Display, Formatter},
    num::ParseIntError,
    str::FromStr,
};

use jiff::civil::Date;
use secrecy::SecretString;
use serde::{Deserialize, Deserializer};

use crate::{
    api_client::ApiClient,
    domain::contents::{Image, ImageSource},
};

/// The address of TMDB's API
const BASE_URL: &str = "https://api.themoviedb.org/3";

/// The address of TMDB's images, which a size and an image's path follow
const IMAGES_URL: &str = "https://image.tmdb.org/t/p";

/// The widths of TMDB's posters, in pixels. It also has the original, whose size it doesn't say.
const POSTER_WIDTHS: [u32; 6] = [92, 154, 185, 342, 500, 780];

/// The widths of TMDB's backdrops, in pixels
const BACKDROP_WIDTHS: [u32; 3] = [300, 780, 1280];

/// The widths of TMDB's photos of people, in pixels
const PROFILE_WIDTHS: [u32; 2] = [45, 185];

/// The widths of TMDB's stills of TV Show Episodes, in pixels
const STILL_WIDTHS: [u32; 3] = [92, 185, 300];

/// The ID of a Movie or a TV Show at TMDB, which numbers Movies and TV Shows apart: a Movie and a TV
/// Show can have the same.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TmdbId(u32);

impl TmdbId {
    pub const fn new(id: u32) -> Self {
        Self(id)
    }
}

impl FromStr for TmdbId {
    type Err = ParseIntError;

    fn from_str(text: &str) -> Result<Self, Self::Err> {
        text.parse().map(Self)
    }
}

impl Display for TmdbId {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// TMDB, signed in with the API Read Access Token of the instance. Clones share their connections.
#[derive(Clone, Debug)]
pub struct Tmdb {
    api: ApiClient,
}

impl Tmdb {
    /// Returns TMDB, signed in with `token`, the instance's API Read Access Token.
    pub fn new(token: &SecretString) -> anyhow::Result<Self> {
        Self::with_base_url(token, BASE_URL)
    }

    /// Returns a TMDB at another address, such as a fake one in tests.
    pub fn with_base_url(token: &SecretString, base_url: &str) -> anyhow::Result<Self> {
        Ok(Self {
            api: ApiClient::new(base_url, Some(token))?,
        })
    }
}

/// Returns the poster at this path on TMDB's image server, in each of its sizes.
fn poster(path: &str) -> Option<Image> {
    // TMDB doesn't say the heights: most posters are 2:3
    image(path, &POSTER_WIDTHS, (2, 3))
}

/// Returns the backdrop at this path on TMDB's image server, in each of its sizes.
fn backdrop(path: &str) -> Option<Image> {
    // Most backdrops are 16:9
    image(path, &BACKDROP_WIDTHS, (16, 9))
}

/// Returns the photo of a person at this path on TMDB's image server, in each of its sizes.
fn profile(path: &str) -> Option<Image> {
    // Most photos of people are 2:3
    image(path, &PROFILE_WIDTHS, (2, 3))
}

/// Returns the still of a TV Show Episode at this path on TMDB's image server, in each of its
/// sizes.
fn still(path: &str) -> Option<Image> {
    // Most stills are 16:9
    image(path, &STILL_WIDTHS, (16, 9))
}

/// Returns the image at this path on TMDB's image server, in each of these widths, with the
/// heights that its aspect ratio, `(width, height)`, gives.
fn image(path: &str, widths: &[u32], (ratio_width, ratio_height): (u32, u32)) -> Option<Image> {
    Image::new(widths.iter().map(|&width| ImageSource {
        url: format!("{IMAGES_URL}/w{width}{path}"),
        width,
        height: (width * ratio_height).div_ceil(ratio_width),
    }))
}

/// Reads a text that TMDB sends empty, or null, when it has none.
fn optional_text<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<String>, D::Error> {
    let text = Option::<String>::deserialize(deserializer)?;
    Ok(text.filter(|text| !text.is_empty()))
}

/// Reads a runtime in minutes that TMDB sends as 0, or null, when it doesn't know it.
fn optional_minutes<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<i32>, D::Error> {
    let minutes = Option::<i32>::deserialize(deserializer)?;
    Ok(minutes.filter(|&minutes| minutes > 0))
}

/// Reads a date that TMDB sends as `YYYY-MM-DD`, or empty, or null, when it has none.
fn optional_date<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<Date>, D::Error> {
    optional_text(deserializer)?
        .map(|date| date.parse().map_err(serde::de::Error::custom))
        .transpose()
}
