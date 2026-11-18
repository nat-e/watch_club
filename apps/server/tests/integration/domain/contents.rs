mod metadata_providers {
    mod tmdb;
}

use std::num::NonZeroU32;

use watch_club::domain::{
    accounts::Locale,
    contents::{self, Content, ContentId, ContentType, SearchResults, TmdbId},
};
use wiremock::{
    Mock, ResponseTemplate,
    matchers::{method, path, query_param},
};

use crate::support::{FakeTmdb, fake_tmdb::fixture};

#[tokio::test]
async fn search_finds_movies_and_tv_shows_on_tmdb_without_the_spaces_around_the_query() {
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/search/multi"))
        .and(query_param("query", "amelie"))
        .and(query_param("language", "fr-FR"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("search_multi")))
        .expect(1)
        .mount(&tmdb.server)
        .await;

    let found = contents::search(
        &tmdb.metadata_providers(),
        " amelie ",
        NonZeroU32::MIN,
        Locale::FrFr,
    )
    .await
    .unwrap();

    assert_eq!(found.results.len(), 5);
}

#[tokio::test]
async fn search_matches_nothing_for_a_blank_query_without_asking_tmdb() {
    let tmdb = FakeTmdb::start().await;

    let found = contents::search(
        &tmdb.metadata_providers(),
        "  ",
        NonZeroU32::MIN,
        Locale::EnUs,
    )
    .await
    .unwrap();

    assert_eq!(found, SearchResults::default());
    assert!(tmdb.server.received_requests().await.unwrap().is_empty());
}

#[tokio::test]
async fn look_up_finds_a_movie_on_tmdb() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer("/movie/194", fixture("movie_details")).await;
    let id = ContentId::Movie(TmdbId::new(194));

    let content = contents::look_up(&tmdb.metadata_providers(), id, Locale::FrFr)
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
async fn look_up_finds_a_tv_show_on_tmdb() {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer("/tv/2316", fixture("tv_details")).await;
    let id = ContentId::TvShow(TmdbId::new(2316));

    let content = contents::look_up(&tmdb.metadata_providers(), id, Locale::EnUs)
        .await
        .unwrap();

    assert_eq!(content.title, "The Office");
}

#[test]
fn content_id_reads_the_tmdb_id_of_a_movie_or_a_tv_show() {
    assert_eq!(
        ContentId::parse(ContentType::Movie, "194"),
        Some(ContentId::Movie(TmdbId::new(194)))
    );
    assert_eq!(
        ContentId::parse(ContentType::TvShow, "2316"),
        Some(ContentId::TvShow(TmdbId::new(2316)))
    );
}

#[test]
fn content_id_reads_nothing_from_text_that_cant_be_a_tmdb_id() {
    for text in ["", "amelie", "-1", "1.5", "4294967296"] {
        assert_eq!(ContentId::parse(ContentType::Movie, text), None, "{text}");
    }
}

#[test]
fn content_id_gives_its_type_and_external_id() {
    let id = ContentId::TvShow(TmdbId::new(2316));

    assert_eq!(
        (id.content_type(), id.external_id()),
        (ContentType::TvShow, "2316".to_owned())
    );
}
