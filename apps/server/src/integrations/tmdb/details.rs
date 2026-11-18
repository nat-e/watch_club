//! TMDB's details of a Movie, a TV Show or a season, with what they include: translations, images,
//! credits and videos.

use jiff::civil::Date;
use serde::{Deserialize, Deserializer};

use super::{optional_date, optional_text};

/// A Movie's details, with its texts in the details' language.
#[derive(Clone, Debug, Deserialize)]
pub struct MovieDetails {
    pub id: u32,
    pub title: String,
    pub original_title: String,
    /// The ISO 639-1 code of its original language
    pub original_language: String,
    #[serde(default, deserialize_with = "optional_text")]
    pub overview: Option<String>,
    #[serde(default, deserialize_with = "optional_text")]
    pub tagline: Option<String>,
    #[serde(default, deserialize_with = "optional_text")]
    pub homepage: Option<String>,
    pub poster_path: Option<String>,
    pub backdrop_path: Option<String>,
    pub belongs_to_collection: Option<Collection>,
    #[serde(default, deserialize_with = "optional_date")]
    pub release_date: Option<Date>,
    /// Its length in minutes
    pub runtime: Option<u32>,
    /// Where it is in its life, such as `Released` or `In Production`
    pub status: String,
    #[serde(default)]
    pub genres: Vec<Genre>,
    /// The ISO 3166-1 codes of the countries it comes from
    #[serde(default)]
    pub origin_country: Vec<String>,
    #[serde(default)]
    pub production_companies: Vec<ProductionCompany>,
    #[serde(default)]
    pub production_countries: Vec<ProductionCountry>,
    #[serde(default)]
    pub spoken_languages: Vec<SpokenLanguage>,
    pub imdb_id: Option<String>,
    /// In US dollars, 0 when unknown
    pub budget: u64,
    /// In US dollars, 0 when unknown
    pub revenue: u64,
    pub popularity: f64,
    pub vote_average: f64,
    pub vote_count: u32,
    pub adult: bool,
    /// Whether it's a video rather than a film, such as a concert
    #[serde(default)]
    pub video: bool,
    #[serde(default)]
    pub credits: Credits,
    #[serde(default)]
    pub images: Images,
    #[serde(default)]
    pub videos: Videos,
    #[serde(default, deserialize_with = "translations")]
    pub translations: Vec<Translation<MovieTranslationData>>,
}

/// The collection a Movie belongs to, such as a saga.
#[derive(Clone, Debug, Deserialize)]
pub struct Collection {
    pub id: u32,
    pub name: String,
    pub poster_path: Option<String>,
    pub backdrop_path: Option<String>,
}

/// A company that produced a Movie.
#[derive(Clone, Debug, Deserialize)]
pub struct ProductionCompany {
    pub id: u32,
    pub name: String,
    pub logo_path: Option<String>,
    /// The ISO 3166-1 code of its country, or empty when unknown
    pub origin_country: String,
}

/// A Movie's texts in one language.
#[derive(Clone, Debug, Default, Deserialize)]
pub struct MovieTranslationData {
    #[serde(default, deserialize_with = "optional_text")]
    pub title: Option<String>,
    #[serde(default, deserialize_with = "optional_text")]
    pub overview: Option<String>,
    #[serde(default, deserialize_with = "optional_text")]
    pub tagline: Option<String>,
    #[serde(default, deserialize_with = "optional_text")]
    pub homepage: Option<String>,
    /// Its length in minutes in this version
    pub runtime: Option<u32>,
}

/// A TV Show's details, with its texts in the details' language.
#[derive(Clone, Debug, Deserialize)]
pub struct TvShowDetails {
    pub id: u32,
    pub name: String,
    pub original_name: String,
    /// The ISO 639-1 code of its original language
    pub original_language: String,
    #[serde(default, deserialize_with = "optional_text")]
    pub overview: Option<String>,
    #[serde(default, deserialize_with = "optional_text")]
    pub tagline: Option<String>,
    #[serde(default, deserialize_with = "optional_text")]
    pub homepage: Option<String>,
    pub poster_path: Option<String>,
    pub backdrop_path: Option<String>,
    #[serde(default, deserialize_with = "optional_date")]
    pub first_air_date: Option<Date>,
    #[serde(default, deserialize_with = "optional_date")]
    pub last_air_date: Option<Date>,
    /// Whether new episodes are coming
    #[serde(default)]
    pub in_production: bool,
    /// Where it is in its life, such as `Returning Series` or `Ended`
    pub status: String,
    pub number_of_seasons: Option<u32>,
    pub number_of_episodes: Option<u32>,
    /// The usual lengths of its episodes, in minutes
    #[serde(default)]
    pub episode_run_time: Vec<u32>,
    /// Its seasons, without their episodes
    #[serde(default)]
    pub seasons: Vec<Season>,
    #[serde(default)]
    pub genres: Vec<Genre>,
    /// The ISO 3166-1 codes of the countries it comes from
    #[serde(default)]
    pub origin_country: Vec<String>,
    /// The ISO 639-1 codes of its languages
    #[serde(default)]
    pub languages: Vec<String>,
    #[serde(default)]
    pub production_countries: Vec<ProductionCountry>,
    #[serde(default)]
    pub spoken_languages: Vec<SpokenLanguage>,
    #[serde(default)]
    pub external_ids: ExternalIds,
    pub popularity: f64,
    pub vote_average: f64,
    pub vote_count: u32,
    pub adult: bool,
    #[serde(default)]
    pub credits: Credits,
    #[serde(default)]
    pub images: Images,
    #[serde(default)]
    pub videos: Videos,
    #[serde(default, deserialize_with = "translations")]
    pub translations: Vec<Translation<TvShowTranslationData>>,
}

/// A TV Show's IDs on other sites.
#[derive(Clone, Debug, Default, Deserialize)]
pub struct ExternalIds {
    pub imdb_id: Option<String>,
    pub tvdb_id: Option<u32>,
}

/// A season of a TV Show, without its episodes.
#[derive(Clone, Debug, Deserialize)]
pub struct Season {
    pub id: u32,
    /// 0 for the specials
    pub season_number: u32,
    pub name: String,
    #[serde(default, deserialize_with = "optional_text")]
    pub overview: Option<String>,
    pub poster_path: Option<String>,
    #[serde(default, deserialize_with = "optional_date")]
    pub air_date: Option<Date>,
    #[serde(default)]
    pub episode_count: u32,
    pub vote_average: f64,
}

/// A TV Show's texts in one language.
#[derive(Clone, Debug, Default, Deserialize)]
pub struct TvShowTranslationData {
    #[serde(default, deserialize_with = "optional_text")]
    pub name: Option<String>,
    #[serde(default, deserialize_with = "optional_text")]
    pub overview: Option<String>,
}

/// A season of a TV Show, with its episodes, and its texts in the details' language.
#[derive(Clone, Debug, Deserialize)]
pub struct SeasonDetails {
    pub id: u32,
    /// 0 for the specials
    pub season_number: u32,
    pub name: String,
    #[serde(default, deserialize_with = "optional_text")]
    pub overview: Option<String>,
    pub poster_path: Option<String>,
    #[serde(default, deserialize_with = "optional_date")]
    pub air_date: Option<Date>,
    pub vote_average: f64,
    #[serde(default)]
    pub episodes: Vec<Episode>,
}

/// An episode of a season.
#[derive(Clone, Debug, Deserialize)]
pub struct Episode {
    pub id: u32,
    /// The TMDB ID of its TV Show
    pub show_id: u32,
    pub season_number: u32,
    pub episode_number: u32,
    /// Its place in the TV Show, such as `standard`, `mid_season` or `finale`
    pub episode_type: Option<String>,
    pub name: String,
    #[serde(default, deserialize_with = "optional_text")]
    pub overview: Option<String>,
    #[serde(default, deserialize_with = "optional_date")]
    pub air_date: Option<Date>,
    /// Its length in minutes
    pub runtime: Option<u32>,
    #[serde(default, deserialize_with = "optional_text")]
    pub production_code: Option<String>,
    /// The path of a frame of the episode
    pub still_path: Option<String>,
    pub vote_average: f64,
    pub vote_count: u32,
    #[serde(default)]
    pub crew: Vec<CrewMember>,
    #[serde(default)]
    pub guest_stars: Vec<CastMember>,
}

/// A genre, with its name in the details' language.
#[derive(Clone, Debug, Deserialize)]
pub struct Genre {
    pub id: u32,
    pub name: String,
}

/// A country that produced a Movie or a TV Show.
#[derive(Clone, Debug, Deserialize)]
pub struct ProductionCountry {
    /// Its ISO 3166-1 code
    pub iso_3166_1: String,
    /// Its name in English
    pub name: String,
}

/// A language spoken in a Movie or a TV Show.
#[derive(Clone, Debug, Deserialize)]
pub struct SpokenLanguage {
    /// Its ISO 639-1 code
    pub iso_639_1: String,
    /// Its name in itself
    pub name: String,
    pub english_name: String,
}

/// The texts of a Movie or a TV Show in one language: `MovieTranslationData` or
/// `TvShowTranslationData`.
#[derive(Clone, Debug, Deserialize)]
pub struct Translation<T> {
    /// The ISO 3166-1 code of the language's country
    pub iso_3166_1: String,
    /// The ISO 639-1 code of the language
    pub iso_639_1: String,
    /// The language's name in itself
    pub name: String,
    pub english_name: String,
    #[serde(default)]
    pub data: T,
}

/// Reads the translations, which TMDB nests in an object of their own.
fn translations<'de, D, T>(deserializer: D) -> Result<Vec<Translation<T>>, D::Error>
where
    D: Deserializer<'de>,
    T: Deserialize<'de> + Default,
{
    #[derive(Deserialize)]
    #[serde(bound = "T: Deserialize<'de> + Default")]
    struct Translations<T> {
        translations: Vec<Translation<T>>,
    }
    Ok(Translations::deserialize(deserializer)?.translations)
}

/// The people who play in a Movie or a TV Show, and who make it.
#[derive(Clone, Debug, Default, Deserialize)]
pub struct Credits {
    /// In their billing order
    #[serde(default)]
    pub cast: Vec<CastMember>,
    #[serde(default)]
    pub crew: Vec<CrewMember>,
}

/// A person who plays in a Movie, a TV Show or an episode.
#[derive(Clone, Debug, Deserialize)]
pub struct CastMember {
    pub id: u32,
    pub name: String,
    /// The character they play
    #[serde(default, deserialize_with = "optional_text")]
    pub character: Option<String>,
    pub profile_path: Option<String>,
    /// Their place in the billing, from 0
    pub order: u32,
}

/// A person who works on a Movie, a TV Show or an episode, such as its director.
#[derive(Clone, Debug, Deserialize)]
pub struct CrewMember {
    pub id: u32,
    pub name: String,
    /// Their job on it, such as `Director`
    pub job: String,
    pub profile_path: Option<String>,
}

/// The images of a Movie or a TV Show, in the languages of `IMAGE_LANGUAGES`.
#[derive(Clone, Debug, Default, Deserialize)]
pub struct Images {
    #[serde(default)]
    pub backdrops: Vec<Image>,
    #[serde(default)]
    pub logos: Vec<Image>,
    #[serde(default)]
    pub posters: Vec<Image>,
}

impl Images {
    /// Returns the path of the backdrop to show: one without text first, then a 16:9 one.
    pub fn best_backdrop_path(&self) -> Option<&str> {
        self.backdrops
            .iter()
            .min_by_key(|backdrop| (backdrop.iso_639_1.is_some(), !backdrop.is_16_9()))
            .map(|backdrop| backdrop.file_path.as_str())
    }
}

/// An image, such as a poster.
#[derive(Clone, Debug, Deserialize)]
pub struct Image {
    pub file_path: String,
    pub width: u32,
    pub height: u32,
    /// Its width divided by its height, to 3 decimals
    pub aspect_ratio: f64,
    /// The ISO 639-1 code of the language of its text, or None when it has no text
    pub iso_639_1: Option<String>,
    pub vote_average: f64,
    pub vote_count: u32,
}

impl Image {
    fn is_16_9(&self) -> bool {
        // TMDB rounds it to 1.778
        (self.aspect_ratio - 16.0 / 9.0).abs() < 0.001
    }
}

/// The videos of a Movie or a TV Show, such as its trailers.
#[derive(Clone, Debug, Default, Deserialize)]
pub struct Videos {
    #[serde(default)]
    pub results: Vec<Video>,
}

impl Videos {
    /// Returns the URL of its official YouTube trailer, else of any YouTube trailer, else of a
    /// YouTube teaser.
    pub fn youtube_trailer_url(&self) -> Option<String> {
        let find = |kind: &str, official_only: bool| {
            self.results.iter().find(|video| {
                video.site == "YouTube"
                    && video.kind == kind
                    && (video.official || !official_only)
                    && !video.key.is_empty()
            })
        };
        let trailer = find("Trailer", true)
            .or_else(|| find("Trailer", false))
            .or_else(|| find("Teaser", false))?;
        Some(format!("https://www.youtube.com/watch?v={}", trailer.key))
    }
}

/// A video on another site, such as a trailer on YouTube.
#[derive(Clone, Debug, Deserialize)]
pub struct Video {
    pub id: String,
    /// Its ID on its site
    pub key: String,
    pub name: String,
    /// The site it's on, such as `YouTube` or `Vimeo`
    pub site: String,
    /// Its kind, such as `Trailer`, `Teaser` or `Clip`
    #[serde(rename = "type")]
    pub kind: String,
    /// Whether the studio published it
    pub official: bool,
}
