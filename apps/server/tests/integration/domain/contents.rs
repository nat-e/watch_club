use std::num::NonZeroU32;

use serde_json::{Value, json};
use watch_club::domain::{
    accounts::Locale,
    contents::{self, Content, ContentId, ContentType, LookUpError, SearchResult, SearchResults},
};
use wiremock::{
    Mock, ResponseTemplate,
    matchers::{method, path, query_param},
};

use crate::support::{FakeTmdb, fake_tmdb::fixture};

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

#[tokio::test]
async fn search_returns_the_movies_and_tv_shows_without_the_people() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .and(query_param("query", "amelie"))
        .and(query_param("page", "1"))
        .and(query_param("language", "fr-FR"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("search_multi")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let found = contents::search(&tmdb.client(), " amelie ", NonZeroU32::MIN, Locale::FrFr)
        .await
        .unwrap();

    assert_eq!(found.results.len(), 5);
    assert_eq!(
        found.results[0],
        SearchResult {
            id: ContentId {
                content_type: ContentType::Movie,
                tmdb_id: 194,
            },
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
    assert_eq!(
        (tv_show.id.content_type, tv_show.id.tmdb_id),
        (ContentType::TvShow, 239_212)
    );
    assert_eq!(tv_show.title, "Amélie and Company");
    assert_eq!(found.next_page, NonZeroU32::new(2));
}

#[tokio::test]
async fn search_leaves_out_the_overview_and_year_tmdb_sends_empty() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer(
        "/search/multi",
        search_page(1, 1, &json!([movie(1, "Untitled")])),
    )
    .await;

    let found = contents::search(&tmdb.client(), "untitled", NonZeroU32::MIN, Locale::EnUs)
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

    let found = contents::search(
        &tmdb.client(),
        "up",
        NonZeroU32::new(3).unwrap(),
        Locale::EnUs,
    )
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

    let found = contents::search(
        &tmdb.client(),
        "the",
        NonZeroU32::new(500).unwrap(),
        Locale::EnUs,
    )
    .await
    .unwrap();

    assert_eq!(found.next_page, None);
}

#[tokio::test]
async fn search_matches_nothing_for_a_blank_query_without_asking_tmdb() {
    let tmdb = FakeTmdb::start().await;

    let found = contents::search(&tmdb.client(), "  ", NonZeroU32::MIN, Locale::EnUs)
        .await
        .unwrap();

    assert_eq!(found, SearchResults::default());
    assert!(tmdb.server.received_requests().await.unwrap().is_empty());
}

#[tokio::test]
async fn look_up_returns_a_movie_with_its_title_in_the_locales_language() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/movie/194"))
        .and(query_param("language", "fr-FR"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("movie_details")))
        .expect(1)
        .mount(&tmdb.server)
        .await;
    let id = ContentId {
        content_type: ContentType::Movie,
        tmdb_id: 194,
    };

    let content = contents::look_up(&tmdb.client(), id, Locale::FrFr)
        .await
        .unwrap();

    assert_eq!(
        content,
        Content {
            id,
            title: "Le Fabuleux Destin d'Amélie Poulain".to_owned(),
        }
    );
}

#[tokio::test]
async fn look_up_returns_a_tv_show() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer("/tv/2316", fixture("tv_details")).await;
    let id = ContentId {
        content_type: ContentType::TvShow,
        tmdb_id: 2316,
    };

    let content = contents::look_up(&tmdb.client(), id, Locale::EnUs)
        .await
        .unwrap();

    assert_eq!(content.title, "The Office");
}

#[tokio::test]
async fn look_up_fails_when_tmdb_has_no_such_content() {
    // Answers 404 to every request
    let tmdb = FakeTmdb::start().await;
    let id = ContentId {
        content_type: ContentType::TvShow,
        tmdb_id: 194,
    };

    let error = contents::look_up(&tmdb.client(), id, Locale::EnUs)
        .await
        .unwrap_err();

    assert!(matches!(error, LookUpError::NotFound), "{error:?}");
}
