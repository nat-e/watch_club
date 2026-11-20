use std::num::NonZeroU32;

use jiff::civil::date;
use serde_json::{Value, json};
use watch_club::domain::{
    accounts::Locale,
    contents::{
        CreditKind, ExternalContentId, Genre, Image, ImageSource, Language, LookUpError, MediaType,
        SearchResult, TmdbId,
    },
};
use wiremock::{
    Mock, ResponseTemplate,
    matchers::{header, method, path, query_param},
};

use crate::support::{
    FakeTmdb,
    fake_tmdb::{TOKEN, fixture},
};

/// Returns TMDB's answer to a search, with these results and pages.
fn search_page(page: u32, total_pages: u32, results: &Value) -> Value {
    json!({"page": page, "results": results, "total_pages": total_pages, "total_results": 20})
}

/// Returns a TMDB search result for a Movie with this ID and title, and nothing else.
fn movie(id: u32, title: &str) -> Value {
    json!({
        "media_type": "movie",
        "id": id,
        "title": title,
        "original_title": title,
        "original_language": "en",
        "overview": "",
        "poster_path": null,
        "backdrop_path": null,
        "genre_ids": [],
        "popularity": 1.0,
        "release_date": "",
        "video": false,
        "vote_average": 0.0,
        "vote_count": 0,
        "adult": false,
    })
}

/// Returns a TMDB search result for a video with this ID and title: what TMDB lists as a movie but
/// flags as not truly one, such as a filmed sports event.
fn video(id: u32, title: &str) -> Value {
    let mut video = movie(id, title);
    video["video"] = json!(true);
    video
}

/// Returns a TMDB search result for a person.
fn person(id: u32) -> Value {
    json!({
        "media_type": "person",
        "id": id,
        "name": "Amélie",
        "original_name": "Amélie",
        "popularity": 1.0,
        "known_for": [],
        "adult": false,
    })
}

#[tokio::test]
async fn search_returns_the_movies_and_tv_shows_without_the_people_in_the_locales_language() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .and(header("authorization", format!("Bearer {TOKEN}")))
        .and(query_param("query", "amélie poulain"))
        .and(query_param("page", "2"))
        .and(query_param("include_adult", "false"))
        .and(query_param("language", "fr-FR"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("search_multi")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let found = tmdb
        .client()
        .search("amélie poulain", NonZeroU32::new(2).unwrap(), Locale::FrFr)
        .await
        .unwrap();

    assert_eq!(found.results.len(), 5);
    assert_eq!(
        found.results[0],
        SearchResult {
            external_content_id: ExternalContentId::Movie(TmdbId::new(194)),
            title: "Amélie".to_owned(),
            date: Some(date(2001, 4, 25)),
            overview: Some(
                "At a tiny Parisian café, the adorable yet painfully shy Amélie accidentally \
                 discovers a gift for helping others. Soon Amelie is spending her days as a \
                 matchmaker, guardian angel, and all-around do-gooder. But when she bumps into a \
                 handsome stranger, will she find the courage to become the star of her very own \
                 love story?"
                    .to_owned()
            ),
            poster: Image::new(
                [
                    (92, 138),
                    (154, 231),
                    (185, 278),
                    (342, 513),
                    (500, 750),
                    (780, 1170)
                ]
                .map(|(width, height)| ImageSource {
                    url: format!(
                        "https://image.tmdb.org/t/p/w{width}/nSxDa3M9aMvGVLoItzWTepQ5h5d.jpg"
                    ),
                    width,
                    height,
                })
            ),
            creators: Vec::new(),
        }
    );
    assert_eq!(found.results[2].poster, None);
    let tv_show = &found.results[4];
    assert_eq!(
        tv_show.external_content_id,
        ExternalContentId::TvShow(TmdbId::new(239_212))
    );
    assert_eq!(tv_show.title, "Amélie and Company");
    assert!(tv_show.poster.is_some());
    // The fixture is TMDB's first page of 43
    assert_eq!(found.next_page, NonZeroU32::new(2));
}

#[tokio::test]
async fn search_leaves_out_the_videos() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer(
        "/search/multi",
        search_page(
            1,
            1,
            &json!([
                video(1_228_562, "UFC 300: Pereira vs. Hill"),
                movie(1366, "Rocky")
            ]),
        ),
    )
    .await;

    let found = tmdb
        .client()
        .search("ufc", NonZeroU32::MIN, Locale::EnUs)
        .await
        .unwrap();

    let titles: Vec<_> = found.results.iter().map(|result| &result.title).collect();
    assert_eq!(titles, ["Rocky"]);
}

#[tokio::test]
async fn search_reads_the_next_page_when_one_has_only_people_and_videos() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .and(query_param("page", "1"))
        .respond_with(ResponseTemplate::new(200).set_body_json(search_page(
            1,
            3,
            &json!([person(1), video(4, "Amélie Live")]),
        )))
        .expect(1)
        .mount(&tmdb.server)
        .await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .and(query_param("page", "2"))
        .respond_with(ResponseTemplate::new(200).set_body_json(search_page(
            2,
            3,
            &json!([person(2), movie(3, "Amélie")]),
        )))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let found = tmdb
        .client()
        .search("amélie", NonZeroU32::MIN, Locale::EnUs)
        .await
        .unwrap();

    let titles: Vec<_> = found.results.iter().map(|result| &result.title).collect();
    assert_eq!(titles, ["Amélie"]);
    assert_eq!(found.next_page, NonZeroU32::new(3));
}

#[tokio::test]
async fn search_reads_5_pages_at_most() {
    let tmdb = FakeTmdb::start().await;
    for page in 1..=5 {
        Mock::given(method("GET"))
            .and(path("/search/multi"))
            .and(query_param("page", page.to_string()))
            .respond_with(ResponseTemplate::new(200).set_body_json(search_page(
                page,
                10,
                &json!([person(page)]),
            )))
            .expect(1)
            .mount(&tmdb.server)
            .await;
    }

    let found = tmdb
        .client()
        .search("amélie", NonZeroU32::MIN, Locale::EnUs)
        .await
        .unwrap();

    assert_eq!(found.results, []);
    assert_eq!(found.next_page, NonZeroU32::new(6));
}

#[tokio::test]
async fn search_leaves_out_the_overview_and_date_tmdb_sends_empty() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer(
        "/search/multi",
        search_page(1, 1, &json!([movie(1, "Untitled")])),
    )
    .await;

    let found = tmdb
        .client()
        .search("untitled", NonZeroU32::MIN, Locale::EnUs)
        .await
        .unwrap();

    let result = &found.results[0];
    assert_eq!((result.date, result.overview.as_deref()), (None, None));
}

#[tokio::test]
async fn search_has_no_next_page_on_the_last_one() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer("/search/multi", search_page(3, 3, &json!([movie(1, "Up")])))
        .await;

    let found = tmdb
        .client()
        .search("up", NonZeroU32::new(3).unwrap(), Locale::EnUs)
        .await
        .unwrap();

    assert_eq!(found.next_page, None);
}

#[tokio::test]
async fn search_stops_at_the_last_page_tmdb_serves() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer(
        "/search/multi",
        search_page(500, 1000, &json!([movie(1, "The")])),
    )
    .await;

    let found = tmdb
        .client()
        .search("the", NonZeroU32::new(500).unwrap(), Locale::EnUs)
        .await
        .unwrap();

    assert_eq!(found.next_page, None);
}

#[tokio::test]
async fn search_fails_with_what_tmdb_says_went_wrong() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .respond_with(ResponseTemplate::new(401).set_body_json(json!({
            "success": false,
            "status_code": 7,
            "status_message": "Invalid API key: You must be granted a valid key.",
        })))
        .mount(&tmdb.server)
        .await;

    let error = tmdb
        .client()
        .search("amelie", NonZeroU32::MIN, Locale::EnUs)
        .await
        .unwrap_err();

    let error = format!("{error:#}");
    assert!(
        error.starts_with("127.0.0.1 answered GET /search/multi with 401 Unauthorized: {"),
        "{error}"
    );
    assert!(
        error.contains("Invalid API key: You must be granted a valid key."),
        "{error}"
    );
}

#[tokio::test]
async fn search_fails_when_tmdb_has_no_search() {
    // Answers 404 to every request
    let tmdb = FakeTmdb::start().await;

    let error = tmdb
        .client()
        .search("amelie", NonZeroU32::MIN, Locale::EnUs)
        .await
        .unwrap_err();

    assert_eq!(
        format!("{error:#}"),
        "TMDB answered GET /search/multi with 404 Not Found"
    );
}

#[tokio::test]
async fn search_tries_again_when_tmdb_is_briefly_unavailable() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .respond_with(ResponseTemplate::new(503))
        .up_to_n_times(1)
        .expect(1)
        .with_priority(1)
        .mount(&tmdb.server)
        .await;
    tmdb.answer("/search/multi", fixture("search_multi")).await;

    let found = tmdb
        .client()
        .search("amelie", NonZeroU32::MIN, Locale::EnUs)
        .await
        .unwrap();

    assert_eq!(found.results.len(), 5);
}

#[tokio::test]
async fn search_gives_up_after_two_more_tries() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .respond_with(ResponseTemplate::new(503))
        .expect(3)
        .mount(&tmdb.server)
        .await;

    let error = tmdb
        .client()
        .search("amelie", NonZeroU32::MIN, Locale::EnUs)
        .await
        .unwrap_err();

    assert!(
        error.to_string().contains("503 Service Unavailable"),
        "{error:#}"
    );
}

#[tokio::test]
async fn fetch_movie_asks_for_everything_in_every_locales_language_at_once() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/movie/194"))
        .and(header("authorization", format!("Bearer {TOKEN}")))
        .and(query_param("language", "en-US"))
        .and(query_param(
            "append_to_response",
            "translations,images,videos,credits,external_ids",
        ))
        .and(query_param("include_image_language", "en,fr,null"))
        .and(query_param("include_video_language", "en,fr"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("movie_details")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let movie = tmdb.client().fetch_movie(TmdbId::new(194)).await.unwrap();

    assert_eq!(movie.id, ExternalContentId::Movie(TmdbId::new(194)));
}

#[tokio::test]
async fn fetch_movie_returns_its_metadata_with_its_one_media() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;

    let movie = tmdb.client().fetch_movie(TmdbId::new(194)).await.unwrap();

    assert_eq!(movie.original_title, "Le Fabuleux Destin d'Amélie Poulain");
    assert_eq!(movie.original_language.as_deref(), Some("fr"));
    assert_eq!(movie.origin_country.as_deref(), Some("FR"));
    assert_eq!(movie.release_date, Some(date(2001, 4, 25)));
    assert_eq!(movie.genres, [Genre::Comedy, Genre::Romance]);
    assert_eq!(movie.rating, Some(7.9));
    assert_eq!(movie.external_ids.imdb.as_deref(), Some("tt0211915"));
    // The backdrop without text, rather than the most voted one
    assert_eq!(
        movie.backdrop.unwrap().sources()[0].url,
        "https://image.tmdb.org/t/p/w300/6n53UI4mX9QMfe2S0Pgt8mGebY1.jpg"
    );
    assert_eq!(movie.media.len(), 1);
    assert_eq!(movie.media[0].media_type, MediaType::Movie);
    assert_eq!(movie.media[0].runtime_seconds, Some(122 * 60));
}

#[tokio::test]
async fn fetch_movie_returns_its_director_then_its_actors_in_billing_order() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;

    let movie = tmdb.client().fetch_movie(TmdbId::new(194)).await.unwrap();

    let credits: Vec<_> = movie
        .credits
        .iter()
        .map(|credit| {
            (
                credit.kind,
                credit.name.as_str(),
                credit.character.as_deref(),
            )
        })
        .collect();
    assert_eq!(
        credits,
        [
            (CreditKind::Director, "Jean-Pierre Jeunet", None),
            (CreditKind::Actor, "Audrey Tautou", Some("Amélie Poulain")),
            (
                CreditKind::Actor,
                "Mathieu Kassovitz",
                Some("Nino Quincampoix")
            ),
            (CreditKind::Actor, "Rufus", Some("Raphaël Poulain")),
            (CreditKind::Actor, "Serge Merlin", Some("Raymond Dufayel")),
        ]
    );
    assert_eq!(movie.credits[0].external_ids.tmdb.as_deref(), Some("2419"));
}

#[tokio::test]
async fn fetch_movie_titles_its_original_languages_translation_with_its_original_title() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;

    let movie = tmdb.client().fetch_movie(TmdbId::new(194)).await.unwrap();

    // TMDB leaves the title of the original language's translation empty
    let french = Language::new("fr", Some("FR".to_owned()));
    assert!(
        movie
            .texts
            .titles
            .translated
            .contains(&(french, "Le Fabuleux Destin d'Amélie Poulain".to_owned())),
        "{:?}",
        movie.texts.titles
    );
}

#[tokio::test]
async fn fetch_movie_returns_its_youtube_trailers_by_language_the_best_first() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;

    let movie = tmdb.client().fetch_movie(TmdbId::new(194)).await.unwrap();

    // Leaves out the clips and featurettes, and puts the trailers before the teasers
    let trailers: Vec<_> = movie
        .texts
        .trailer_urls
        .translated
        .iter()
        .map(|(language, url)| (language.code.as_str(), url.as_str()))
        .collect();
    assert_eq!(
        trailers,
        [
            ("fr", "https://www.youtube.com/watch?v=_cZyjM_R6-E"),
            ("en", "https://www.youtube.com/watch?v=j0aotpJRPgc"),
            ("en", "https://www.youtube.com/watch?v=NkvJh8cpVCE"),
        ]
    );
}

#[tokio::test]
async fn fetch_tv_show_returns_its_episodes_with_their_texts_in_each_locale() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;

    let tv_show = tmdb
        .client()
        .fetch_tv_show(TmdbId::new(87_108))
        .await
        .unwrap();

    assert_eq!(tv_show.original_title, "Chernobyl");
    assert_eq!(tv_show.external_ids.tvdb.as_deref(), Some("360893"));
    assert_eq!(tv_show.media.len(), 5);
    let episode = &tv_show.media[1];
    assert_eq!(episode.media_type, MediaType::TvShowEpisode);
    assert_eq!(
        (episode.group_number, episode.number_in_group),
        (Some(1), Some(2))
    );
    assert_eq!(episode.release_date, Some(date(2019, 5, 13)));
    assert_eq!(episode.runtime_seconds, Some(66 * 60));
    assert!(episode.image.is_some());
    assert_eq!(
        episode.texts.titles.translated,
        [
            (
                Language::new("en", Some("US".to_owned())),
                "Please Remain Calm".to_owned()
            ),
            (
                Language::new("fr", Some("FR".to_owned())),
                "Veuillez garder votre calme".to_owned()
            ),
        ]
    );
}

#[tokio::test]
async fn fetch_tv_show_asks_for_the_seasons_it_didnt_guess_20_at_a_time_in_each_locale() {
    let tmdb = FakeTmdb::start().await;
    // Season 0 holds the specials, which WatchClub leaves out
    let first_seasons = season_appends(1..=15);
    Mock::given(method("GET"))
        .and(path("/tv/456"))
        .and(query_param("language", "en-US"))
        .and(query_param(
            "append_to_response",
            format!("translations,images,videos,credits,external_ids,{first_seasons}"),
        ))
        .respond_with(ResponseTemplate::new(200).set_body_json(tv_show(0..=37, 1..=15)))
        .expect(1)
        .mount(&tmdb.server)
        .await;
    for (language, seasons) in [
        ("en-US", 16..=35),
        ("en-US", 36..=37),
        ("fr-FR", 1..=20),
        ("fr-FR", 21..=37),
    ] {
        Mock::given(method("GET"))
            .and(path("/tv/456"))
            .and(query_param("language", language))
            .and(query_param(
                "append_to_response",
                season_appends(seasons.clone()),
            ))
            .respond_with(ResponseTemplate::new(200).set_body_json(appended_seasons(seasons)))
            .expect(1)
            .mount(&tmdb.server)
            .await;
    }

    let tv_show = tmdb.client().fetch_tv_show(TmdbId::new(456)).await.unwrap();

    let seasons: Vec<_> = tv_show
        .media
        .iter()
        .filter_map(|episode| episode.group_number)
        .collect();
    assert_eq!(seasons, (1..=37).collect::<Vec<_>>());
}

#[tokio::test]
async fn fetch_tv_show_leaves_out_the_titles_tmdb_makes_up_for_untranslated_episodes() {
    let tmdb = FakeTmdb::start().await;
    let mut details = tv_show(1..=1, 1..=1);
    details["season/1"]["episodes"][0]["name"] = json!("Pilot");
    details["season/1"]["episodes"][0]["overview"] = json!("Walter starts cooking.");
    let mut french = appended_seasons(1..=1);
    french["season/1"]["episodes"][0]["name"] = json!("Épisode 1");
    french["season/1"]["episodes"][0]["overview"] = json!("");
    tmdb.answer_in("/tv/456", Locale::EnUs, details).await;
    tmdb.answer_in("/tv/456", Locale::FrFr, french).await;

    let tv_show = tmdb.client().fetch_tv_show(TmdbId::new(456)).await.unwrap();

    let texts = &tv_show.media[0].texts;
    let english = Language::new("en", Some("US".to_owned()));
    assert_eq!(
        texts.titles.translated,
        [(english.clone(), "Pilot".to_owned())]
    );
    assert_eq!(
        texts.overviews.translated,
        [(english, "Walter starts cooking.".to_owned())]
    );
}

#[tokio::test]
async fn fetch_tv_show_takes_tmdbs_runtime_of_0_as_unknown() {
    let tmdb = FakeTmdb::start().await;
    let mut details = tv_show(1..=1, 1..=1);
    details["season/1"]["episodes"][0]["runtime"] = json!(0);
    tmdb.answer_in("/tv/456", Locale::EnUs, details).await;
    tmdb.answer_in("/tv/456", Locale::FrFr, appended_seasons(1..=1))
        .await;

    let tv_show = tmdb.client().fetch_tv_show(TmdbId::new(456)).await.unwrap();

    assert_eq!(tv_show.media[0].runtime_seconds, None);
}

#[tokio::test]
async fn fetch_fails_with_not_found_when_tmdb_has_nothing_with_the_id() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/tv/194"))
        .respond_with(ResponseTemplate::new(404).set_body_json(json!({
            "success": false,
            "status_code": 34,
            "status_message": "The resource you requested could not be found.",
        })))
        .mount(&tmdb.server)
        .await;

    let error = tmdb
        .client()
        .fetch_tv_show(TmdbId::new(194))
        .await
        .unwrap_err();

    assert!(matches!(error, LookUpError::NotFound), "{error:?}");
}

/// Returns TMDB's `append_to_response` for these seasons, such as `season/1,season/2`.
fn season_appends(seasons: impl IntoIterator<Item = i32>) -> String {
    seasons
        .into_iter()
        .map(|season| format!("season/{season}"))
        .collect::<Vec<_>>()
        .join(",")
}

/// Returns the details of a TV Show with these seasons, and nothing else, with the `appended`
/// ones.
fn tv_show(
    seasons: impl IntoIterator<Item = i32>,
    appended: impl IntoIterator<Item = i32>,
) -> Value {
    let mut details = json!({
        "original_name": "The Simpsons",
        "original_language": "en",
        "seasons": seasons
            .into_iter()
            .map(|season| json!({"season_number": season}))
            .collect::<Vec<_>>(),
        "translations": {"translations": []},
        "images": {"posters": [], "backdrops": []},
        "videos": {"results": []},
        "credits": {"cast": [], "crew": []},
        "external_ids": {},
    });
    details
        .as_object_mut()
        .unwrap()
        .extend(appended_seasons(appended).as_object().unwrap().clone());
    details
}

/// Returns a TV Show's details with only these seasons, of one TV Show Episode each.
fn appended_seasons(seasons: impl IntoIterator<Item = i32>) -> Value {
    seasons
        .into_iter()
        .map(|season| {
            let episode = json!({"episode_number": 1, "name": format!("Season {season} premiere")});
            (
                format!("season/{season}"),
                json!({"season_number": season, "episodes": [episode]}),
            )
        })
        .collect()
}
