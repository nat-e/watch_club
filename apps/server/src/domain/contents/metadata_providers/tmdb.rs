//! TMDB, The Movie Database: the Metadata Provider of Movies and TV Shows.
//!
//! A Movie's or a TV Show's details come in one request, which brings what every Locale shares, and
//! the texts, posters and trailers in every language: TMDB's translations, and its images and
//! videos in each Locale's language. A TV Show's Episodes come in `tv_show`, and the credits'
//! details in `credits`.
//!
//! Trailers and TV Show Episodes' texts are only in the Locales' languages, so they have no original
//! language to fall back on. That would take more requests for little: TMDB has English summaries
//! and trailers for nearly every show, and only some lack English titles for their TV Show
//! Episodes, which then show their number only.

mod credits;
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

use self::{
    credits::Credits,
    tv_show::{AppendedSeasons, SeasonSummary},
};
use crate::{
    api_client::ApiClient,
    domain::{
        accounts::Locale,
        contents::{
            ContentMetadata, ContentTranslations, ExternalContentId, ExternalIds, Genre, Image,
            ImageSource, Language, LookUpError, MediaMetadata, MediaTranslations, MediaType,
            Translations,
        },
    },
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

/// The Locale of the details request, which also brings what every Locale shares
const BASE_LOCALE: Locale = Locale::EnUs;

/// What the details request adds to a Movie's or a TV Show's details
const DETAILS_APPENDS: [&str; 5] = [
    "translations",
    "images",
    "videos",
    "credits",
    "external_ids",
];

/// The number of requests TMDB adds to one with `append_to_response` at most: more fail it
const MAX_APPENDS: usize = 20;

/// The number of votes below which a Content has no rating, as a single vote of 10 would otherwise
/// top the best rated
const MIN_VOTES: u32 = 25;

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

    /// Returns the Movie with this ID, in every language TMDB has it.
    pub async fn fetch_movie(&self, id: TmdbId) -> Result<ContentMetadata, LookUpError> {
        let movie = self
            .details("/movie/{id}", id, &[])
            .await?
            .ok_or(LookUpError::NotFound)?;

        let media = MediaMetadata {
            media_type: MediaType::Movie,
            group_number: None,
            number_in_group: None,
            release_date: movie.release_date,
            runtime_seconds: movie.runtime.and_then(minutes_to_seconds),
            image: None,
            texts: MediaTranslations::default(),
        };
        Ok(movie.into_metadata(ExternalContentId::Movie(id), vec![media]))
    }

    /// Returns the details of the Movie or TV Show at `route`, such as `/movie/{id}`, with these
    /// seasons, or None when TMDB doesn't know it.
    async fn details(
        &self,
        route: &'static str,
        id: TmdbId,
        seasons: &[i32],
    ) -> anyhow::Result<Option<Details>> {
        let appends = DETAILS_APPENDS
            .into_iter()
            .map(str::to_owned)
            .chain(seasons.iter().map(|number| format!("season/{number}")))
            .collect::<Vec<_>>()
            .join(",");
        // Without them, TMDB only sends the images and videos in the request's language. Images
        // without a language have no text, such as most backdrops
        let languages = Locale::ALL.map(Locale::language).join(",");
        let image_languages = format!("{languages},null");

        self.api
            .get(
                route,
                &[&id.to_string()],
                &[
                    ("language", BASE_LOCALE.language_tag()),
                    ("append_to_response", &appends),
                    ("include_image_language", &image_languages),
                    ("include_video_language", &languages),
                ],
            )
            .await
    }
}

/// Returns a runtime in seconds from TMDB's minutes, or None for TMDB's 0, which means it doesn't
/// know.
fn minutes_to_seconds(minutes: i32) -> Option<i32> {
    (minutes > 0).then(|| minutes.saturating_mul(60))
}

/// The details of a Movie or a TV Show, with what `DETAILS_APPENDS` adds. TMDB names some fields
/// differently for each: a TV Show's `name` is a Movie's `title`.
#[derive(Debug, Deserialize)]
struct Details {
    #[serde(alias = "original_name")]
    original_title: String,
    #[serde(default, deserialize_with = "optional_text")]
    original_language: Option<String>,
    /// The countries it comes from, the main one first
    #[serde(default)]
    origin_country: Vec<String>,
    /// The countries it was made in, which some Movies have without an origin country
    #[serde(default)]
    production_countries: Vec<Country>,
    #[serde(default, alias = "first_air_date", deserialize_with = "optional_date")]
    release_date: Option<Date>,
    #[serde(default)]
    genres: Vec<GenreReference>,
    #[serde(default)]
    vote_average: f32,
    #[serde(default)]
    vote_count: u32,
    poster_path: Option<String>,
    backdrop_path: Option<String>,
    /// A Movie's runtime, in minutes
    runtime: Option<i32>,
    /// A TV Show's seasons
    #[serde(default)]
    seasons: Vec<SeasonSummary>,
    translations: TranslationList,
    images: Images,
    videos: VideoList,
    credits: Credits,
    external_ids: TmdbExternalIds,
    /// A TV Show's seasons that the request asked for
    #[serde(flatten)]
    appended_seasons: AppendedSeasons,
}

impl Details {
    /// Returns the Content's metadata, with these Media.
    fn into_metadata(self, id: ExternalContentId, media: Vec<MediaMetadata>) -> ContentMetadata {
        let texts = self.texts();
        let backdrop = self
            .images
            .backdrops
            .iter()
            // Backdrops without a language have no text
            .find(|image| image.iso_639_1.is_none())
            .map(|image| image.file_path.as_str())
            .or(self.backdrop_path.as_deref())
            .and_then(backdrop);
        let origin_country = self
            .origin_country
            .into_iter()
            .chain(
                self.production_countries
                    .into_iter()
                    .map(|country| country.iso_3166_1),
            )
            .next();
        let rating =
            (self.vote_count >= MIN_VOTES).then(|| (self.vote_average * 10.0).round() / 10.0);

        ContentMetadata {
            id,
            external_ids: ExternalIds {
                imdb: self.external_ids.imdb_id,
                tvdb: self.external_ids.tvdb_id.map(|id| id.to_string()),
                ..ExternalIds::default()
            },
            original_title: self.original_title,
            original_language: self.original_language,
            origin_country,
            release_date: self.release_date,
            genres: genres(&self.genres),
            rating,
            backdrop,
            texts,
            credits: self.credits.into_metadata(),
            media,
        }
    }

    /// Returns the Content's texts, posters and trailers in every language TMDB has them.
    fn texts(&self) -> ContentTranslations {
        let original_language = self.original_language.as_deref();
        let is_original =
            |translation: &&Translation| Some(translation.iso_639_1.as_str()) == original_language;

        let titles =
            self.translations
                .translations
                .iter()
                .filter_map(|translation| {
                    // TMDB leaves the title of the original language's translation empty
                    let title = translation.data.title.clone().or_else(|| {
                        is_original(&translation).then(|| self.original_title.clone())
                    })?;
                    Some((translation.language(), title))
                })
                .collect();
        let overviews = self
            .translations
            .translations
            .iter()
            .filter_map(|translation| {
                Some((translation.language(), translation.data.overview.clone()?))
            })
            .collect();
        let original_overview = self
            .translations
            .translations
            .iter()
            .filter(is_original)
            .find_map(|translation| translation.data.overview.clone());
        let posters = self
            .images
            .posters
            .iter()
            .filter_map(|image| {
                let language = Language::new(image.iso_639_1.clone()?, image.iso_3166_1.clone());
                Some((language, poster(&image.file_path)?))
            })
            .collect();

        ContentTranslations {
            titles: Translations {
                original: None,
                translated: titles,
            },
            overviews: Translations {
                original: original_overview,
                translated: overviews,
            },
            posters: Translations {
                // TMDB's main poster, which may have no text
                original: self.poster_path.as_deref().and_then(poster),
                translated: posters,
            },
            trailer_urls: Translations {
                original: None,
                translated: trailers(&self.videos.results),
            },
        }
    }
}

/// Returns the YouTube URL of each trailer, by language, the best first: the official trailers,
/// then the others, then the teasers.
fn trailers(videos: &[Video]) -> Vec<(Language, String)> {
    let mut trailers: Vec<_> = videos
        .iter()
        .filter(|video| video.site == "YouTube" && !video.key.is_empty())
        .filter_map(|video| {
            let rank = match (video.kind.as_str(), video.official) {
                ("Trailer", true) => 0,
                ("Trailer", false) => 1,
                ("Teaser", _) => 2,
                _ => return None,
            };
            Some((rank, video))
        })
        .collect();
    trailers.sort_by_key(|(rank, _)| *rank);

    trailers
        .into_iter()
        .map(|(_, video)| {
            let language = Language::new(video.iso_639_1.clone(), Some(video.iso_3166_1.clone()));
            (
                language,
                format!("https://www.youtube.com/watch?v={}", video.key),
            )
        })
        .collect()
}

/// Returns the genres of TMDB's genres, once each, leaving out those TMDB added after this list.
fn genres(tmdb_genres: &[GenreReference]) -> Vec<Genre> {
    let mut genres = Vec::new();
    for &genre in tmdb_genres.iter().flat_map(|genre| genres_of(genre.id)) {
        if !genres.contains(&genre) {
            genres.push(genre);
        }
    }
    genres
}

/// Returns the genres of a TMDB genre, by its ID: TMDB's TV genres that combine two give both. From
/// <https://developer.themoviedb.org/reference/genre-movie-list> and
/// <https://developer.themoviedb.org/reference/genre-tv-list>.
fn genres_of(tmdb_genre_id: u32) -> &'static [Genre] {
    match tmdb_genre_id {
        28 => &[Genre::Action],
        12 => &[Genre::Adventure],
        16 => &[Genre::Animation],
        35 => &[Genre::Comedy],
        80 => &[Genre::Crime],
        99 => &[Genre::Documentary],
        18 => &[Genre::Drama],
        10_751 => &[Genre::Family],
        14 => &[Genre::Fantasy],
        36 => &[Genre::History],
        27 => &[Genre::Horror],
        10_402 => &[Genre::Music],
        9648 => &[Genre::Mystery],
        10_749 => &[Genre::Romance],
        878 => &[Genre::ScienceFiction],
        10_770 => &[Genre::TvMovie],
        53 => &[Genre::Thriller],
        10_752 => &[Genre::War],
        37 => &[Genre::Western],
        10_759 => &[Genre::Action, Genre::Adventure],
        10_762 => &[Genre::Kids],
        10_763 => &[Genre::News],
        10_764 => &[Genre::Reality],
        10_765 => &[Genre::ScienceFiction, Genre::Fantasy],
        10_766 => &[Genre::Soap],
        10_767 => &[Genre::Talk],
        10_768 => &[Genre::War, Genre::Politics],
        _ => &[],
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

/// A country a Movie was made in.
#[derive(Debug, Deserialize)]
struct Country {
    iso_3166_1: String,
}

/// A genre, by its TMDB ID.
#[derive(Debug, Deserialize)]
struct GenreReference {
    id: u32,
}

/// The translations of a Content's texts.
#[derive(Debug, Deserialize)]
struct TranslationList {
    translations: Vec<Translation>,
}

/// A Content's texts in one language, which are empty when nobody translated them.
#[derive(Debug, Deserialize)]
struct Translation {
    iso_639_1: String,
    iso_3166_1: String,
    data: TranslationData,
}

impl Translation {
    fn language(&self) -> Language {
        Language::new(self.iso_639_1.clone(), Some(self.iso_3166_1.clone()))
    }
}

/// The texts of a translation. A TV Show's `name` is a Movie's `title`.
#[derive(Debug, Deserialize)]
struct TranslationData {
    #[serde(default, alias = "name", deserialize_with = "optional_text")]
    title: Option<String>,
    #[serde(default, deserialize_with = "optional_text")]
    overview: Option<String>,
}

/// A Content's posters and backdrops, the most voted first.
#[derive(Debug, Deserialize)]
struct Images {
    #[serde(default)]
    posters: Vec<ImageInfo>,
    #[serde(default)]
    backdrops: Vec<ImageInfo>,
}

/// A poster or a backdrop, and the language of its text, if it has any.
#[derive(Debug, Deserialize)]
struct ImageInfo {
    file_path: String,
    iso_639_1: Option<String>,
    #[serde(default)]
    iso_3166_1: Option<String>,
}

/// A Content's videos.
#[derive(Debug, Deserialize)]
struct VideoList {
    results: Vec<Video>,
}

/// A video about a Content, such as a trailer, on a site such as YouTube.
#[derive(Debug, Deserialize)]
struct Video {
    iso_639_1: String,
    iso_3166_1: String,
    /// Its ID on its site
    key: String,
    site: String,
    /// Such as `Trailer`, `Teaser` or `Featurette`
    #[serde(rename = "type")]
    kind: String,
    #[serde(default)]
    official: bool,
}

/// A Content's IDs in other catalogs.
#[derive(Debug, Deserialize)]
struct TmdbExternalIds {
    #[serde(default, deserialize_with = "optional_text")]
    imdb_id: Option<String>,
    /// A TV Show's ID at TheTVDB
    tvdb_id: Option<u32>,
}

/// Reads a text that TMDB sends empty, or null, when it has none.
fn optional_text<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<String>, D::Error> {
    let text = Option::<String>::deserialize(deserializer)?;
    Ok(text.filter(|text| !text.is_empty()))
}

/// Reads a date that TMDB sends as `YYYY-MM-DD`, or empty, or null, when it has none.
fn optional_date<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Option<Date>, D::Error> {
    optional_text(deserializer)?
        .map(|date| date.parse().map_err(serde::de::Error::custom))
        .transpose()
}
