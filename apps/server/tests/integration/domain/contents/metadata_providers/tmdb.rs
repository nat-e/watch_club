use std::num::NonZeroU32;

use serde_json::{Value, json};
use watch_club::domain::{
    accounts::Locale,
    contents::{Content, ContentId, LookUpError, SearchResult, TmdbId},
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
            id: ContentId::Movie(TmdbId::new(194)),
            title: "Amélie".to_owned(),
            year: Some(2001),
            overview: Some(
                "At a tiny Parisian café, the adorable yet painfully shy Amélie accidentally \
                 discovers a gift for helping others. Soon Amelie is spending her days as a \
                 matchmaker, guardian angel, and all-around do-gooder. But when she bumps into a \
                 handsome stranger, will she find the courage to become the star of her very own \
                 love story?"
                    .to_owned()
            ),
            poster_path: Some("/nSxDa3M9aMvGVLoItzWTepQ5h5d.jpg".to_owned()),
        }
    );
    let tv_show = &found.results[4];
    assert_eq!(tv_show.id, ContentId::TvShow(TmdbId::new(239_212)));
    assert_eq!(tv_show.title, "Amélie and Company");
    // The fixture is TMDB's first page of 43
    assert_eq!(found.next_page, NonZeroU32::new(2));
}

#[tokio::test]
async fn search_reads_the_next_page_when_one_has_only_people() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .and(query_param("page", "1"))
        .respond_with(ResponseTemplate::new(200).set_body_json(search_page(
            1,
            3,
            &json!([person(1)]),
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
async fn search_leaves_out_the_overview_and_year_tmdb_sends_empty() {
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
    assert_eq!((result.year, result.overview.as_deref()), (None, None));
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
async fn look_up_movie_returns_its_title_in_the_locales_language() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/movie/194"))
        .and(header("authorization", format!("Bearer {TOKEN}")))
        .and(query_param("language", "fr-FR"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("movie_details")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let content = tmdb
        .client()
        .look_up_movie(TmdbId::new(194), Locale::FrFr)
        .await
        .unwrap();

    assert_eq!(
        content,
        Content {
            id: ContentId::Movie(TmdbId::new(194)),
            title: "Le Fabuleux Destin d'Amélie Poulain".to_owned(),
        }
    );
}

#[tokio::test]
async fn look_up_tv_show_returns_its_title_in_the_locales_language() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/tv/2316"))
        .and(query_param("language", "en-US"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("tv_details")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let content = tmdb
        .client()
        .look_up_tv_show(TmdbId::new(2316), Locale::EnUs)
        .await
        .unwrap();

    assert_eq!(
        content,
        Content {
            id: ContentId::TvShow(TmdbId::new(2316)),
            title: "The Office".to_owned(),
        }
    );
}

#[tokio::test]
async fn look_up_fails_with_not_found_when_tmdb_has_nothing_with_the_id() {
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
        .look_up_tv_show(TmdbId::new(194), Locale::EnUs)
        .await
        .unwrap_err();

    assert!(matches!(error, LookUpError::NotFound), "{error:?}");
}
