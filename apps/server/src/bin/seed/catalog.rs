//! The dev catalog in `dev/catalog/media`, which the seed saves: its Contents, by External ID, and
//! the Sources of the Radarr, Sonarr and Sportarr that `pnpm catalog` runs. It saves every Content,
//! as only Radarr's files import yet.

use watch_club::domain::{
    contents::{
        ExternalContentId,
        metadata::{SportarrId, TmdbId},
    },
    sources::servarr::ServarrApp,
};

/// A Source of one of the catalog's apps, with the Source Configuration of the catalog's snapshot.
pub struct CatalogSource {
    pub app: ServarrApp,
    pub url: &'static str,
    pub api_key: &'static str,
    pub quality_profile_id: i32,
    pub root_folder_path: &'static str,
    /// The root folder in the primary worktree, which docker-compose.dev.yml mounts in the app
    pub local_root_folder: &'static str,
}

/// The Sources of the catalog's apps
pub const SOURCES: [CatalogSource; 3] = [
    CatalogSource {
        app: ServarrApp::Radarr,
        url: "http://localhost:4103",
        api_key: "bda1c59d732041b6b519f84d38478ca0",
        quality_profile_id: 1,
        root_folder_path: "/media/radarr",
        local_root_folder: "tmp/catalog/radarr",
    },
    CatalogSource {
        app: ServarrApp::Sonarr,
        url: "http://localhost:4104",
        api_key: "24388b48b19d420f9df41ba1976e5cc6",
        quality_profile_id: 1,
        root_folder_path: "/media/sonarr",
        local_root_folder: "tmp/catalog/sonarr",
    },
    CatalogSource {
        app: ServarrApp::Sportarr,
        url: "http://localhost:4105",
        api_key: "cd24fe4dbb484e0fa9079e51edb71038",
        quality_profile_id: 1,
        root_folder_path: "/media/sportarr",
        local_root_folder: "tmp/catalog/sportarr",
    },
];

/// The catalog's Movies, by TMDB ID
#[expect(
    clippy::unreadable_literal,
    reason = "IDs read as in TMDB's URLs, without separators"
)]
const MOVIES: [u32; 97] = [
    1696028, // 096 (2020)
    30266,   // 20,000 Leagues Under the Sea (1916)
    2964,    // A Trip to Mars (1918)
    28974,   // A Woman of Paris - A Drama of Fate (1923)
    1385292, // Ada & Zangemann - A Tale of Software, Skateboards, and Raspberry Ice Cream (2024)
    87300,   // Alice in Wonderland (1915)
    643,     // Battleship Potemkin (1925)
    1605817, // Beware of Bunny (2015)
    10378,   // Big Buck Bunny (2008)
    70806,   // Blind Husbands (1919)
    899,     // Broken Blossoms or The Yellow Man and the Girl (1919)
    885487,  // Butterflies (2018)
    253774,  // Caminandes - Gran Dillama (2013)
    253777,  // Caminandes - Llama Drama (2013)
    406956,  // Caminandes - Llamigos (2016)
    1062079, // Charge (2022)
    717986,  // Coffee Run (2020)
    1123203, // Colourful (2018)
    358332,  // Cosmos Laundromat (2015)
    472796,  // Dominion (2018)
    42366,   // Dr. Jack (1922)
    9761,    // Elephants Dream (2006)
    510913,  // Eskimal (2011)
    35227,   // Foolish Wives (1922)
    386502,  // Fox Tale (2015)
    40574,   // Girl Shy (1924)
    420577,  // Glass Half (2015)
    33015,   // Go West (1925)
    1405,    // Greed (1924)
    615324,  // HERO (2018)
    3085,    // His Girl Friday (1940)
    3059,    // Intolerance - Love's Struggle Throughout the Ages (1916)
    259800,  // Little Tombstone (2011)
    26317,   // Man with a Movie Camera (1929)
    435712,  // Midnight Snack (2014)
    498193,  // My Moon (2017)
    10331,   // Night of the Living Dead (1968)
    1631991, // No Need to Rush Life (2022)
    477375,  // Orang-U - An Ape Goes to College (2017)
    42511,   // Orphans of the Storm (1921)
    505920,  // Other Lily (2017)
    139893,  // Panopticon (2012)
    548013,  // Paywall - The Business of Scholarship (2018)
    1072528, // Pendatang (2023)
    120672,  // Peter Pan (1924)
    435704,  // Pine Devil (2016)
    10513,   // Plan 9 from Outer Space (1957)
    498198,  // Reticulum Rex (2003)
    596433,  // Roadkill (2019)
    71066,   // Robin Hood (1922)
    96951,   // Salomé (1923)
    32600,   // Seven Chances (1925)
    342831,  // Sherlock Holmes (1916)
    992,     // Sherlock Jr. (1924)
    1687677, // Singularity (2026)
    45745,   // Sintel (2010)
    688900,  // Sol Levante (2020)
    22595,   // Speedy (1928)
    1119357, // Spirit Chaser (2016)
    593048,  // Spring (2019)
    891761,  // Sprite Fright (2024)
    70753,   // Stella Maris (1918)
    28391,   // Street Angel (1928)
    133701,  // Tears of Steel (2012)
    37833,   // Tell Your Children (1938)
    234,     // The Cabinet of Dr. Caligari (1920)
    31411,   // The Cameraman (1928)
    76804,   // The Cat and the Canary (1927)
    498482,  // The Daily Dweebs (2017)
    48256,   // The Doll (1919)
    31432,   // The Four Horsemen of the Apocalypse (1921)
    962,     // The Gold Rush (1925)
    84880,   // The Great White Silence (1924)
    2974,    // The Hands of Orlac (1924)
    6793,    // The Haunted Castle (1921)
    41462,   // The Hitch-Hiker (1953)
    18987,   // The Hunchback of Notre Dame (1923)
    71068,   // The Iron Horse (1925)
    10098,   // The Kid (1921)
    16661,   // The Kid Brother (1927)
    52679,   // The Last Command (1928)
    24452,   // The Little Shop of Horrors (1960)
    96713,   // The Marriage Circle (1924)
    32318,   // The Navigator (1924)
    48591,   // The Oyster Princess (1919)
    86081,   // The Regeneration (1915)
    51392,   // The Saphead (1920)
    36841,   // The Sheik (1921)
    28963,   // The Thief of Bagdad (1924)
    55648,   // The Wildcat (1921)
    47508,   // The Wizard of Oz (1925)
    36106,   // True Heart Susie (1919)
    42565,   // Underworld (1927)
    27522,   // Waxworks (1924)
    31509,   // Way Down East (1920)
    26860,   // White Zombie (1932)
    1177628, // Wing It! (2023)
];

/// The catalog's TV Shows, by TMDB ID
const TV_SHOWS: [u32; 2] = [
    84836, // BBS: The Documentary (2005)
    1018,  // Bonanza (1959), which Sonarr knows by its TVDB ID, 73378
];

/// The catalog's Sports Events, by sportarr.net ID
const SPORTS_EVENTS: [&str; 5] = [
    "ev-2621992", // DTM 2019, Norisring
    "ev-174596",  // Formula E 2015, Punta del Este ePrix
    "ev-174620",  // Formula E 2017, Mexico City ePrix
    "ev-369578",  // WRC 2022, Croatia Rally
    "ev-369605",  // WRC 2024, Croatia Rally
];

/// Returns the External IDs of the catalog's Contents: its Movies, TV Shows and Sports Events.
pub fn external_content_ids() -> Vec<ExternalContentId> {
    let movies = MOVIES.map(|id| ExternalContentId::Movie(TmdbId::new(id)));
    let tv_shows = TV_SHOWS.map(|id| ExternalContentId::TvShow(TmdbId::new(id)));
    let sports_events = SPORTS_EVENTS.map(|id| ExternalContentId::SportsEvent(SportarrId::new(id)));
    movies
        .into_iter()
        .chain(tv_shows)
        .chain(sports_events)
        .collect()
}
