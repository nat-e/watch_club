//! The details of a Movie or a TV Show at TMDB, with its TV Show Episodes, in every Locale.
//!
//! One request brings what every Locale shares, and the texts, posters and trailers in every
//! language: TMDB's translations, and its images and videos in each Locale's language. TMDB only
//! translates TV Show Episodes in the language of the request, so each Locale has its own requests
//! for them, which add up to 20 seasons each to the TV Show's details with `append_to_response`.
//!
//! Trailers and TV Show Episodes' texts are only in the Locales' languages, so they have no original
//! language to fall back on. That would take more requests for little: TMDB has English summaries
//! and trailers for nearly every show, and only some lack English titles for their TV Show
//! Episodes, which then show their number only.

use std::{collections::BTreeMap, fmt, mem};

use anyhow::Context;
use jiff::civil::Date;
use serde::{
    Deserialize, Deserializer,
    de::{IgnoredAny, MapAccess, Visitor},
};

use super::{Tmdb, TmdbId, backdrop, optional_date, optional_text, poster, profile, still};
use crate::domain::{
    accounts::Locale,
    contents::{
        ContentMetadata, ContentTranslations, CreditKind, CreditMetadata, ExternalContentId,
        ExternalIds, Genre, Language, LookUpError, MediaMetadata, MediaTranslations, MediaType,
        Translations,
    },
};

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

/// The number of actors a Content's credits keep, after its director
const MAX_ACTORS: usize = 17;

/// The number of votes below which a Content has no rating, as a single vote of 10 would otherwise
/// top the best rated
const MIN_VOTES: u32 = 25;

impl Tmdb {
    /// Returns the Movie with this ID, in every language TMDB has it.
    pub async fn fetch_movie(&self, id: TmdbId) -> Result<ContentMetadata, LookUpError> {
        let movie = self
            .details("/movie/{id}", id, &[])
            .await?
            .ok_or(LookUpError::NotFound)?;

        let media = MediaMetadata {
            media_type: MediaType::Movie,
            group_number: None,
            number: None,
            release_date: movie.release_date,
            runtime_seconds: movie.runtime.and_then(minutes_to_seconds),
            image: None,
            texts: MediaTranslations::default(),
        };
        Ok(movie.into_metadata(ExternalContentId::Movie(id), vec![media]))
    }

    /// Returns the TV Show with this ID, with its TV Show Episodes from season 1, in every language
    /// TMDB has them.
    pub async fn fetch_tv_show(&self, id: TmdbId) -> Result<ContentMetadata, LookUpError> {
        // Asks for the first seasons before knowing which exist, which TMDB leaves out when they
        // don't: most TV Shows then need no other request in the base Locale
        let guessed_seasons: Vec<i32> = (1..).take(MAX_APPENDS - DETAILS_APPENDS.len()).collect();
        let mut tv_show = self
            .details("/tv/{id}", id, &guessed_seasons)
            .await?
            .ok_or(LookUpError::NotFound)?;

        // Season 0 holds the specials, which WatchClub leaves out
        let season_numbers: Vec<i32> = tv_show
            .seasons
            .iter()
            .map(|season| season.season_number)
            .filter(|&number| number >= 1)
            .collect();
        let mut seasons_by_locale = Vec::with_capacity(Locale::ALL.len());
        for locale in Locale::ALL {
            let mut seasons = if locale == BASE_LOCALE {
                mem::take(&mut tv_show.appended_seasons.0)
            } else {
                Vec::new()
            };
            let missing: Vec<i32> = season_numbers
                .iter()
                .copied()
                .filter(|&number| !seasons.iter().any(|season| season.season_number == number))
                .collect();
            for numbers in missing.chunks(MAX_APPENDS) {
                seasons.extend(self.seasons(id, numbers, locale).await?);
            }
            seasons_by_locale.push((locale, seasons));
        }

        let media = episodes(seasons_by_locale);
        Ok(tv_show.into_metadata(ExternalContentId::TvShow(id), media))
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

    /// Returns the TV Show's seasons with these numbers, at most `MAX_APPENDS`, with their TV Show
    /// Episodes' texts in the Locale's language.
    async fn seasons(
        &self,
        id: TmdbId,
        numbers: &[i32],
        locale: Locale,
    ) -> anyhow::Result<Vec<Season>> {
        let appends = numbers
            .iter()
            .map(|number| format!("season/{number}"))
            .collect::<Vec<_>>()
            .join(",");
        let seasons: AppendedSeasons = self
            .api
            .get(
                "/tv/{id}",
                &[&id.to_string()],
                &[
                    ("language", locale.language_tag()),
                    ("append_to_response", &appends),
                ],
            )
            .await?
            .context("TMDB no longer knows the TV Show")?;
        Ok(seasons.0)
    }
}

/// Returns the TV Show Episodes of the seasons that each Locale's requests brought, by season and
/// number, with their texts in each Locale.
fn episodes(seasons_by_locale: Vec<(Locale, Vec<Season>)>) -> Vec<MediaMetadata> {
    let mut episodes = BTreeMap::new();
    for (locale, seasons) in seasons_by_locale {
        for season in seasons {
            for episode in season.episodes {
                // The fields other than the texts are the same in every language
                let media = episodes
                    .entry((season.season_number, episode.number))
                    .or_insert_with(|| MediaMetadata {
                        media_type: MediaType::TvShowEpisode,
                        group_number: Some(season.season_number),
                        number: Some(episode.number),
                        release_date: episode.air_date,
                        runtime_seconds: episode.runtime.and_then(minutes_to_seconds),
                        image: episode.still_path.as_deref().and_then(still),
                        texts: MediaTranslations::default(),
                    });

                let language = Language::from(locale);
                let title = episode
                    .name
                    .filter(|name| !is_untitled(name, episode.number));
                if let Some(title) = title {
                    media
                        .texts
                        .titles
                        .translated
                        .push((language.clone(), title));
                }
                if let Some(overview) = episode.overview {
                    media.texts.overviews.translated.push((language, overview));
                }
            }
        }
    }
    episodes.into_values().collect()
}

/// Whether a TV Show Episode's title is the one TMDB makes up when it has none in the request's
/// language, such as `Épisode 3`.
fn is_untitled(title: &str, episode_number: i32) -> bool {
    [
        format!("Episode {episode_number}"),
        format!("Épisode {episode_number}"),
    ]
    .contains(&title.to_owned())
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
            credits: credits(self.credits),
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

/// Returns the first director and the first actors, in billing order. A director who acts in their
/// Movie shows once, as its director.
fn credits(credits: Credits) -> Vec<CreditMetadata> {
    let director = credits
        .crew
        .into_iter()
        .find(|member| member.job == "Director")
        .map(|director| {
            (
                director.id,
                CreditKind::Director,
                director.name,
                None,
                director.profile_path,
            )
        });
    let mut cast = credits.cast;
    cast.sort_by_key(|actor| actor.order.unwrap_or(u32::MAX));
    let actors = cast.into_iter().take(MAX_ACTORS).map(|actor| {
        (
            actor.id,
            CreditKind::Actor,
            actor.name,
            actor.character,
            actor.profile_path,
        )
    });

    let mut person_ids = Vec::new();
    director
        .into_iter()
        .chain(actors)
        .filter(|(person_id, ..)| {
            let is_new = !person_ids.contains(person_id);
            person_ids.push(*person_id);
            is_new
        })
        .map(
            |(person_id, kind, name, character, profile_path)| CreditMetadata {
                kind,
                name,
                character,
                photo: profile_path.as_deref().and_then(profile),
                external_ids: ExternalIds {
                    tmdb: Some(person_id.to_string()),
                    ..ExternalIds::default()
                },
            },
        )
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

/// A season in a TV Show's details.
#[derive(Debug, Deserialize)]
struct SeasonSummary {
    season_number: i32,
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

/// The people who made a Content and who are in it.
#[derive(Debug, Deserialize)]
struct Credits {
    #[serde(default)]
    cast: Vec<CastMember>,
    #[serde(default)]
    crew: Vec<CrewMember>,
}

/// An actor, with the character they play.
#[derive(Debug, Deserialize)]
struct CastMember {
    id: u32,
    name: String,
    #[serde(default, deserialize_with = "optional_text")]
    character: Option<String>,
    profile_path: Option<String>,
    /// Their place in the billing, from 0
    order: Option<u32>,
}

/// A person who made a Content, with their job, such as `Director`.
#[derive(Debug, Deserialize)]
struct CrewMember {
    id: u32,
    name: String,
    job: String,
    profile_path: Option<String>,
}

/// A Content's IDs in other catalogs.
#[derive(Debug, Deserialize)]
struct TmdbExternalIds {
    #[serde(default, deserialize_with = "optional_text")]
    imdb_id: Option<String>,
    /// A TV Show's ID at TheTVDB
    tvdb_id: Option<u32>,
}

/// The seasons that a request adds to a TV Show's details, under their `season/{number}` keys,
/// with the TV Show's other fields left out.
#[derive(Debug, Default)]
struct AppendedSeasons(Vec<Season>);

impl<'de> Deserialize<'de> for AppendedSeasons {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        struct SeasonsVisitor;

        impl<'de> Visitor<'de> for SeasonsVisitor {
            type Value = AppendedSeasons;

            fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
                formatter.write_str("a TV Show's details")
            }

            fn visit_map<A: MapAccess<'de>>(self, mut map: A) -> Result<Self::Value, A::Error> {
                let mut seasons = Vec::new();
                while let Some(key) = map.next_key::<String>()? {
                    if key.starts_with("season/") {
                        seasons.push(map.next_value()?);
                    } else {
                        map.next_value::<IgnoredAny>()?;
                    }
                }
                Ok(AppendedSeasons(seasons))
            }
        }

        deserializer.deserialize_map(SeasonsVisitor)
    }
}

/// A season of a TV Show, with its TV Show Episodes' texts in the request's language.
#[derive(Debug, Deserialize)]
struct Season {
    season_number: i32,
    #[serde(default)]
    episodes: Vec<Episode>,
}

/// A TV Show Episode, with its texts in the request's language.
#[derive(Debug, Deserialize)]
struct Episode {
    #[serde(rename = "episode_number")]
    number: i32,
    #[serde(default, deserialize_with = "optional_text")]
    name: Option<String>,
    #[serde(default, deserialize_with = "optional_text")]
    overview: Option<String>,
    #[serde(default, deserialize_with = "optional_date")]
    air_date: Option<Date>,
    /// In minutes
    runtime: Option<i32>,
    still_path: Option<String>,
}
