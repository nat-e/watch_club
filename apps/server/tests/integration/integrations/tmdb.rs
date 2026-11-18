use std::num::NonZeroU32;

use jiff::civil::date;
use serde_json::json;
use watch_club::integrations::tmdb::{ExternalId, KnownFor, MultiSearchResult};
use wiremock::{
    Mock, ResponseTemplate,
    matchers::{header, method, path, query_param},
};

use crate::support::{
    FakeTmdb,
    fake_tmdb::{TOKEN, fixture},
};

const PAGE_2: NonZeroU32 = NonZeroU32::new(2).unwrap();

#[tokio::test]
async fn searches_movies_tv_shows_and_people_in_the_locales_language() {
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

    let page = tmdb
        .client()
        .search_multi("amélie poulain", PAGE_2, "fr-FR")
        .await
        .unwrap();

    assert_eq!(
        (page.page, page.total_pages, page.total_results),
        (1, 43, 845)
    );
    let MultiSearchResult::Movie(movie) = &page.results[0] else {
        panic!("not a Movie: {:?}", page.results[0]);
    };
    assert_eq!(movie.id, 194);
    assert_eq!(movie.title, "Amélie");
    assert_eq!(movie.original_title, "Le Fabuleux Destin d'Amélie Poulain");
    assert_eq!(movie.release_date, Some(date(2001, 4, 25)));
    assert_eq!(
        movie.poster_path.as_deref(),
        Some("/nSxDa3M9aMvGVLoItzWTepQ5h5d.jpg")
    );
    let MultiSearchResult::Person(person) = &page.results[4] else {
        panic!("not a person: {:?}", page.results[4]);
    };
    assert_eq!(person.name, "Amélie Hoeferle");
    assert!(matches!(person.known_for[..], [KnownFor::Movie(_)]));
    let MultiSearchResult::TvShow(tv_show) = &page.results[5] else {
        panic!("not a TV Show: {:?}", page.results[5]);
    };
    assert_eq!(tv_show.name, "Amélie and Company");
    assert_eq!(tv_show.original_name, "Amélie et Compagnie");
}

#[tokio::test]
async fn searches_movies_released_in_a_year() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/movie"))
        .and(query_param("query", "amelie"))
        .and(query_param("primary_release_year", "2001"))
        .and(query_param("language", "fr-FR"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("search_movie")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let page = tmdb
        .client()
        .search_movies("amelie", Some(2001), NonZeroU32::MIN, "fr-FR")
        .await
        .unwrap();

    assert_eq!(page.results[0].id, 194);
    assert_eq!(page.results[0].title, "Le Fabuleux Destin d'Amélie Poulain");
}

#[tokio::test]
async fn searches_tv_shows_first_aired_in_a_year() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/tv"))
        .and(query_param("query", "the office"))
        .and(query_param("first_air_date_year", "2005"))
        .and(query_param("language", "en-US"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("search_tv")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let page = tmdb
        .client()
        .search_tv_shows("the office", Some(2005), NonZeroU32::MIN, "en-US")
        .await
        .unwrap();

    assert!(page.results.iter().any(|tv_show| tv_show.id == 2316));
}

#[tokio::test]
async fn finds_by_imdb_id() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/find/tt0211915"))
        .and(query_param("external_source", "imdb_id"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("find")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let found = tmdb
        .client()
        .find_by_external_id(&ExternalId::Imdb("tt0211915".to_owned()))
        .await
        .unwrap();

    assert_eq!(found.movie_results[0].id, 194);
    assert!(found.tv_results.is_empty());
}

#[tokio::test]
async fn finds_episodes_by_tvdb_id() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/find/110413"))
        .and(query_param("external_source", "tvdb_id"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "movie_results": [],
            "tv_results": [],
            "tv_episode_results": [
                {"id": 170_135, "show_id": 2316, "season_number": 1, "episode_number": 1},
            ],
        })))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let found = tmdb
        .client()
        .find_by_external_id(&ExternalId::Tvdb(110_413))
        .await
        .unwrap();

    let episode = &found.tv_episode_results[0];
    assert_eq!(
        (
            episode.show_id,
            episode.season_number,
            episode.episode_number
        ),
        (2316, 1, 1)
    );
}

#[tokio::test]
async fn escapes_the_ids_in_paths() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/find/tt1%2F..%2Fmovie"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({})))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    tmdb.client()
        .find_by_external_id(&ExternalId::Imdb("tt1/../movie".to_owned()))
        .await
        .unwrap();
}

#[tokio::test]
async fn returns_a_movies_details_with_its_translations_images_credits_and_videos() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/movie/194"))
        .and(query_param("language", "fr-FR"))
        .and(query_param(
            "append_to_response",
            "translations,images,credits,videos",
        ))
        .and(query_param("include_image_language", "en,fr,null"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("movie_details")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let movie = tmdb
        .client()
        .movie_details(194, "fr-FR")
        .await
        .unwrap()
        .unwrap();

    assert_eq!(movie.title, "Le Fabuleux Destin d'Amélie Poulain");
    assert_eq!(movie.release_date, Some(date(2001, 4, 25)));
    assert_eq!(movie.runtime, Some(120));
    assert_eq!(movie.imdb_id.as_deref(), Some("tt0211915"));
    assert_eq!(movie.genres[0].name, "Comédie");
    assert_eq!(movie.credits.cast[0].name, "Audrey Tautou");
    assert_eq!(
        movie.credits.cast[0].character.as_deref(),
        Some("Amélie Poulain")
    );
    let english = movie
        .translations
        .iter()
        .find(|translation| translation.iso_639_1 == "en")
        .unwrap();
    assert_eq!(english.data.title.as_deref(), Some("Amélie"));
    assert_eq!(
        movie.images.best_backdrop_path(),
        Some("/6n53UI4mX9QMfe2S0Pgt8mGebY1.jpg")
    );
    assert_eq!(
        movie.videos.youtube_trailer_url().as_deref(),
        Some("https://www.youtube.com/watch?v=_cZyjM_R6-E")
    );
}

#[tokio::test]
async fn returns_a_tv_shows_details_with_its_seasons_and_ids_on_other_sites() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/tv/2316"))
        .and(query_param("language", "en-US"))
        .and(query_param(
            "append_to_response",
            "translations,images,external_ids,credits,videos",
        ))
        .and(query_param("include_image_language", "en,fr,null"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("tv_details")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let tv_show = tmdb
        .client()
        .tv_show_details(2316, "en-US")
        .await
        .unwrap()
        .unwrap();

    assert_eq!(tv_show.name, "The Office");
    assert_eq!(tv_show.first_air_date, Some(date(2005, 3, 24)));
    assert_eq!(tv_show.number_of_seasons, Some(9));
    assert_eq!(tv_show.external_ids.tvdb_id, Some(73244));
    assert_eq!(tv_show.external_ids.imdb_id.as_deref(), Some("tt0386676"));
    assert_eq!(tv_show.seasons[1].name, "Season 1");
    assert_eq!(tv_show.seasons[1].episode_count, 6);
    // TMDB sends an empty overview for the specials
    assert_eq!(tv_show.seasons[0].overview, None);
    assert!(
        tv_show
            .translations
            .iter()
            .any(|translation| translation.iso_639_1 == "fr")
    );
}

#[tokio::test]
async fn returns_a_season_with_its_episodes() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/tv/2316/season/1"))
        .and(query_param("language", "en-US"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("season_details")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let season = tmdb
        .client()
        .season_details(2316, 1, "en-US")
        .await
        .unwrap()
        .unwrap();

    assert_eq!(season.name, "Season 1");
    let pilot = &season.episodes[0];
    assert_eq!((pilot.episode_number, pilot.name.as_str()), (1, "Pilot"));
    assert_eq!(pilot.air_date, Some(date(2005, 3, 24)));
    assert_eq!(pilot.crew[0].job, "Director");
    assert_eq!(
        pilot.guest_stars[0].character.as_deref(),
        Some("Roy Anderson")
    );
}

#[tokio::test]
async fn returns_none_when_tmdb_has_nothing_with_the_id() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/movie/999999999"))
        .respond_with(ResponseTemplate::new(404).set_body_json(json!({
            "success": false,
            "status_code": 34,
            "status_message": "The resource you requested could not be found.",
        })))
        .mount(&tmdb.server)
        .await;

    let movie = tmdb
        .client()
        .movie_details(999_999_999, "en-US")
        .await
        .unwrap();

    assert!(movie.is_none());
}

#[tokio::test]
async fn fails_when_tmdb_has_no_search() {
    // The fake TMDB answers 404 to the routes no test mounts
    let tmdb = FakeTmdb::start().await;

    let error = tmdb
        .client()
        .search_multi("amelie", NonZeroU32::MIN, "en-US")
        .await
        .unwrap_err();

    assert_eq!(
        format!("{error:#}"),
        "TMDB answered /search/multi with 404 Not Found"
    );
}

#[tokio::test]
async fn fails_with_what_tmdb_says_went_wrong() {
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
        .search_multi("amelie", NonZeroU32::MIN, "en-US")
        .await
        .unwrap_err();

    assert_eq!(
        format!("{error:#}"),
        "TMDB answered /search/multi with 401 Unauthorized: Invalid API key: You must be granted \
         a valid key."
    );
}

#[tokio::test]
async fn tries_again_when_tmdb_is_briefly_unavailable() {
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

    let page = tmdb
        .client()
        .search_multi("amelie", NonZeroU32::MIN, "en-US")
        .await
        .unwrap();

    assert_eq!(page.total_results, 845);
}

#[tokio::test]
async fn gives_up_after_two_more_tries() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .respond_with(ResponseTemplate::new(503))
        .expect(3)
        .mount(&tmdb.server)
        .await;

    let error = tmdb
        .client()
        .search_multi("amelie", NonZeroU32::MIN, "en-US")
        .await
        .unwrap_err();

    assert!(
        error.to_string().contains("503 Service Unavailable"),
        "{error:#}"
    );
}
