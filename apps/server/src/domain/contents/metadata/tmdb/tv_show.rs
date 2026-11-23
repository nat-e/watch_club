//! A TV Show at TMDB, with its TV Show Episodes from season 1, in every Locale.
//!
//! TMDB only translates TV Show Episodes in the language of the request, so each Locale has its own
//! requests for them, which add up to 20 seasons each to the TV Show's details with
//! `append_to_response`. The details request asks for the first seasons in the base Locale.

use std::{collections::BTreeMap, fmt, mem};

use anyhow::Context;
use jiff::civil::Date;
use serde::{
    Deserialize, Deserializer,
    de::{IgnoredAny, MapAccess, Visitor},
};

use super::{
    Tmdb, TmdbId,
    details::{BASE_LOCALE, DETAILS_APPENDS, MAX_APPENDS},
    optional_date, optional_minutes, optional_text, still,
};
use crate::{
    domain::{
        accounts::preferences::Locale,
        contents::{
            ExternalContentId, Language, MediaTranslations, MediaType,
            metadata::{ContentMetadata, MediaMetadata},
        },
    },
    utils::time::minutes_to_seconds,
};

impl Tmdb {
    /// Returns the TV Show with this ID, with its TV Show Episodes from season 1, in every language
    /// TMDB has them, or None when TMDB doesn't know it.
    pub async fn fetch_tv_show(&self, id: TmdbId) -> anyhow::Result<Option<ContentMetadata>> {
        // Asks for the first seasons before knowing which exist, which TMDB leaves out when they
        // don't: most TV Shows then need no other request in the base Locale
        let guessed_seasons: Vec<i32> = (1..).take(MAX_APPENDS - DETAILS_APPENDS.len()).collect();
        let Some(mut tv_show) = self.details("/tv/{id}", id, &guessed_seasons).await? else {
            return Ok(None);
        };

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
        Ok(Some(
            tv_show.into_metadata(ExternalContentId::TvShow(id), media),
        ))
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
            .await
            .context("failed to fetch a TV Show's seasons from TMDB")?
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
                        number_in_group: Some(episode.number),
                        release_date: episode.air_date,
                        runtime_seconds: episode.runtime.map(minutes_to_seconds),
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

/// A season in a TV Show's details.
#[derive(Debug, Deserialize)]
pub(super) struct SeasonSummary {
    season_number: i32,
}

/// The seasons that a request adds to a TV Show's details, under their `season/{number}` keys,
/// with the TV Show's other fields left out.
#[derive(Debug, Default)]
pub(super) struct AppendedSeasons(Vec<Season>);

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
    #[serde(default, deserialize_with = "optional_minutes")]
    runtime: Option<i32>,
    still_path: Option<String>,
}
