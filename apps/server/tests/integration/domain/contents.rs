mod image;
mod metadata {
    mod hardcover;
    mod sportarr;
    mod tmdb;
}

use std::num::NonZeroU32;

use jiff::civil::date;
use serde_json::json;
use sqlx::PgPool;
use watch_club::{
    db::Pool,
    domain::{
        accounts::preferences::Locale,
        contents::{
            self, ContentId, ContentType, ExternalContentId, SearchResults, SearchScope,
            metadata::{HardcoverId, MetadataProviders, SportarrId, TmdbId},
        },
    },
    jobs::{self, JobContext},
};
use watch_club_test_macros::database_test;
use wiremock::{
    Mock, ResponseTemplate,
    matchers::{method, path, query_param},
};

use crate::support::{
    self, FakeHardcover, FakeSportarr, FakeTmdb, fake_hardcover, fake_sportarr,
    fake_tmdb::{self, fixture},
};

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
        SearchScope::MoviesAndTvShows,
        NonZeroU32::MIN,
        Locale::FrFr,
    )
    .await
    .unwrap();

    assert_eq!(found.results.len(), 5);
}

#[tokio::test]
async fn search_finds_sports_events_on_sportarr() {
    let sportarr = FakeSportarr::start().await;
    sportarr
        .answer(
            "/search/event/canelo",
            fake_sportarr::fixture("search_events"),
        )
        .await;

    let found = contents::search(
        &sportarr.metadata_providers(),
        "canelo",
        SearchScope::SportsEvents,
        NonZeroU32::MIN,
        Locale::FrFr,
    )
    .await
    .unwrap();

    assert_eq!(found.results[0].title, "Canelo Álvarez vs Christian Mbilli");
}

#[tokio::test]
async fn search_finds_books_on_hardcover() {
    let hardcover = FakeHardcover::start().await;
    hardcover
        .answer("SearchBooks", fake_hardcover::fixture("search_books"))
        .await;

    let found = contents::search(
        &hardcover.metadata_providers(),
        "asterix",
        SearchScope::Books,
        NonZeroU32::MIN,
        Locale::FrFr,
    )
    .await
    .unwrap();

    assert_eq!(found.results[0].title, "Asterix the Gaul");
}

#[tokio::test]
async fn search_matches_nothing_for_a_blank_query_without_asking_tmdb() {
    let tmdb = FakeTmdb::start().await;

    let found = contents::search(
        &tmdb.metadata_providers(),
        "  ",
        SearchScope::MoviesAndTvShows,
        NonZeroU32::MIN,
        Locale::EnUs,
    )
    .await
    .unwrap();

    assert_eq!(found, SearchResults::default());
    assert!(tmdb.server.received_requests().await.unwrap().is_empty());
}

#[database_test]
async fn get_by_external_id_saves_a_movie_the_first_time_and_reads_it_after(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path("/movie/194"))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("movie_details")))
        .expect(1)
        .mount(&tmdb.server)
        .await;
    let providers = tmdb.metadata_providers();

    let first = contents::get_by_external_id(&db, &providers, amelie(), Locale::FrFr)
        .await
        .unwrap()
        .unwrap();
    let second = contents::get_by_external_id(&db, &providers, amelie(), Locale::FrFr)
        .await
        .unwrap()
        .unwrap();

    assert_eq!(first, second);
    assert_eq!(first.title, "Le Fabuleux Destin d'Amélie Poulain");
    assert_eq!(first.runtime_seconds, Some(122 * 60));
    assert_eq!(first.media_group_count, 0);
    assert_eq!(first.credits.len(), 5);
    assert_eq!(queued_refreshes(&db).await, 0);
}

#[database_test]
async fn get_by_external_id_returns_the_texts_in_the_locale_or_else_in_english(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;
    let providers = tmdb.metadata_providers();

    let english = contents::get_by_external_id(&db, &providers, amelie(), Locale::EnUs)
        .await
        .unwrap()
        .unwrap();
    let french = contents::get_by_external_id(&db, &providers, chernobyl(), Locale::FrFr)
        .await
        .unwrap()
        .unwrap();

    assert_eq!(english.title, "Amélie");
    assert_eq!(
        english.trailer_url.as_deref(),
        Some("https://www.youtube.com/watch?v=j0aotpJRPgc")
    );
    // TMDB has no French title, but a French overview
    assert_eq!(french.title, "Chernobyl");
    assert!(french.overview.unwrap().starts_with("L'histoire vraie"));
    assert_eq!(french.media_group_count, 1);
    assert_eq!(french.runtime_seconds, None);
}

#[database_test]
async fn get_by_external_id_queues_a_refresh_of_a_content_saved_over_a_day_ago(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;
    let providers = tmdb.metadata_providers();
    let saved = contents::get_by_external_id(&db, &providers, amelie(), Locale::EnUs)
        .await
        .unwrap()
        .unwrap();
    make_stale(&db, saved.id).await;

    let content = contents::get_by_external_id(&db, &providers, amelie(), Locale::EnUs)
        .await
        .unwrap()
        .unwrap();

    assert_eq!(content, saved);
    assert_eq!(queued_refreshes(&db).await, 1);
}

#[database_test]
async fn get_by_external_id_returns_a_saved_content_when_tmdb_is_down(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;
    let saved =
        contents::get_by_external_id(&db, &tmdb.metadata_providers(), amelie(), Locale::EnUs)
            .await
            .unwrap()
            .unwrap();
    make_stale(&db, saved.id).await;

    let content = contents::get_by_external_id(
        &db,
        &support::unreachable_metadata_providers(),
        amelie(),
        Locale::EnUs,
    )
    .await
    .unwrap()
    .unwrap();

    assert_eq!(content, saved);
}

#[database_test]
async fn get_by_external_id_is_none_when_tmdb_has_no_such_content(db: PgPool) {
    let db = watch_club::db::instrument(db);
    // Answers 404 to every request
    let tmdb = FakeTmdb::start().await;

    let content =
        contents::get_by_external_id(&db, &tmdb.metadata_providers(), amelie(), Locale::EnUs)
            .await
            .unwrap();

    assert_eq!(content, None);
}

#[database_test]
async fn get_by_external_id_saves_a_sports_event_and_a_book(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let sportarr = FakeSportarr::start().await;
    sportarr
        .answer("/lookup/event/ev-575969", fake_sportarr::fixture("event"))
        .await;
    let hardcover = FakeHardcover::start().await;
    hardcover
        .answer("Book", fake_hardcover::fixture("book"))
        .await;
    let providers = MetadataProviders {
        tmdb: fake_tmdb::unreachable(),
        sportarr: sportarr.client(),
        hardcover: hardcover.client(),
    };
    let event_id = ExternalContentId::SportsEvent(SportarrId::new("ev-575969"));
    let book_id = ExternalContentId::Book(HardcoverId::new(442_623));

    let event = contents::get_by_external_id(&db, &providers, event_id, Locale::FrFr)
        .await
        .unwrap()
        .unwrap();
    let book = contents::get_by_external_id(&db, &providers, book_id, Locale::FrFr)
        .await
        .unwrap()
        .unwrap();

    assert_eq!(event.title, "Canelo Álvarez vs Edgar Berlanga");
    assert_eq!(event.credits[0].name, "Boxing");
    assert_eq!(book.title, "Asterix the Gaul");
    assert_eq!(book.credits.len(), 2);
}

#[database_test]
async fn list_media_lists_the_episodes_in_order_with_their_texts_in_the_locale(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;
    let tv_show =
        contents::get_by_external_id(&db, &tmdb.metadata_providers(), chernobyl(), Locale::EnUs)
            .await
            .unwrap()
            .unwrap();

    let episodes = contents::list_media(&db, tv_show.id, Locale::FrFr)
        .await
        .unwrap();

    let numbers: Vec<_> = episodes
        .iter()
        .map(|episode| (episode.group_number, episode.number_in_group))
        .collect();
    assert_eq!(
        numbers,
        (1..=5)
            .map(|number| (Some(1), Some(number)))
            .collect::<Vec<_>>()
    );
    assert_eq!(
        episodes[1].title.as_deref(),
        Some("Veuillez garder votre calme")
    );
    assert_eq!(episodes[1].release_date, Some(date(2019, 5, 13)));
    assert_eq!(episodes[1].runtime_seconds, Some(66 * 60));
}

#[database_test]
async fn refresh_saves_what_changed_and_deletes_the_episodes_tmdb_no_longer_lists(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;
    let tv_show =
        contents::get_by_external_id(&db, &tmdb.metadata_providers(), chernobyl(), Locale::EnUs)
            .await
            .unwrap()
            .unwrap();
    make_stale(&db, tv_show.id).await;
    let mut details = fixture("tv_details");
    details["name"] = json!("Tchernobyl");
    details["translations"]["translations"] = json!([]);
    details["original_name"] = json!("Tchernobyl");
    details["season/1"]["episodes"]
        .as_array_mut()
        .unwrap()
        .truncate(3);
    let mut french = fixture("tv_seasons_fr");
    french["season/1"]["episodes"]
        .as_array_mut()
        .unwrap()
        .truncate(3);
    let refreshed_tmdb = FakeTmdb::start().await;
    refreshed_tmdb
        .answer_in("/tv/87108", Locale::EnUs, details)
        .await;
    refreshed_tmdb
        .answer_in("/tv/87108", Locale::FrFr, french)
        .await;
    let context = JobContext {
        db: db.clone(),
        metadata_providers: refreshed_tmdb.metadata_providers(),
    };
    contents::get_by_external_id(&db, &context.metadata_providers, chernobyl(), Locale::EnUs)
        .await
        .unwrap()
        .unwrap();

    jobs::run_available(&context).await.unwrap();

    let content =
        contents::get_by_external_id(&db, &context.metadata_providers, chernobyl(), Locale::EnUs)
            .await
            .unwrap()
            .unwrap();
    assert_eq!(content.id, tv_show.id);
    assert_eq!(content.title, "Tchernobyl");
    let episodes = contents::list_media(&db, tv_show.id, Locale::EnUs)
        .await
        .unwrap();
    assert_eq!(episodes.len(), 3);
    assert_eq!(queued_refreshes(&db).await, 0);
}

#[database_test]
async fn refresh_keeps_a_content_tmdb_no_longer_knows(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;
    let saved =
        contents::get_by_external_id(&db, &tmdb.metadata_providers(), amelie(), Locale::EnUs)
            .await
            .unwrap()
            .unwrap();
    // Answers 404 to every request
    let empty_tmdb = FakeTmdb::start().await;

    contents::refresh(&db, &empty_tmdb.metadata_providers(), saved.id)
        .await
        .unwrap();

    let content = contents::get_by_external_id(
        &db,
        &empty_tmdb.metadata_providers(),
        amelie(),
        Locale::EnUs,
    )
    .await
    .unwrap()
    .unwrap();
    assert_eq!(content, saved);
}

/// Returns the External ID of the Movie of `fixtures/tmdb`, Amélie.
fn amelie() -> ExternalContentId {
    ExternalContentId::Movie(TmdbId::new(fake_tmdb::MOVIE_ID))
}

/// Returns the External ID of the TV Show of `fixtures/tmdb`, Chernobyl.
fn chernobyl() -> ExternalContentId {
    ExternalContentId::TvShow(TmdbId::new(fake_tmdb::TV_SHOW_ID))
}

/// Marks the Content as saved two days ago.
async fn make_stale(db: &Pool, content_id: ContentId) {
    sqlx::query!(
        "UPDATE contents SET metadata_refreshed_at = now() - interval '2 days' WHERE id = $1",
        content_id as ContentId,
    )
    .execute(db)
    .await
    .unwrap();
}

/// Returns the number of refreshes of a Content waiting in the queue.
async fn queued_refreshes(db: &Pool) -> i64 {
    sqlx::query_scalar!(
        r#"
        SELECT count(*) AS "count!" FROM jobs
        WHERE kind = 'refresh_content' AND state = 'available'
        "#
    )
    .fetch_one(db)
    .await
    .unwrap()
}

#[test]
fn external_content_id_reads_the_tmdb_id_of_a_movie_or_a_tv_show() {
    assert_eq!(
        ExternalContentId::parse(ContentType::Movie, "194"),
        Some(ExternalContentId::Movie(TmdbId::new(194)))
    );
    assert_eq!(
        ExternalContentId::parse(ContentType::TvShow, "2316"),
        Some(ExternalContentId::TvShow(TmdbId::new(2316)))
    );
}

#[test]
fn external_content_id_reads_the_hardcover_id_of_a_book() {
    assert_eq!(
        ExternalContentId::parse(ContentType::Book, "442623"),
        Some(ExternalContentId::Book(HardcoverId::new(442_623)))
    );
    for text in ["asterix", "2147483648"] {
        assert_eq!(
            ExternalContentId::parse(ContentType::Book, text),
            None,
            "{text}"
        );
    }
}

#[test]
fn external_content_id_reads_the_sportarr_id_of_a_sports_event() {
    assert_eq!(
        ExternalContentId::parse(ContentType::SportsEvent, "ev-028133"),
        Some(ExternalContentId::SportsEvent(SportarrId::new("ev-028133")))
    );
}

#[test]
fn external_content_id_reads_nothing_from_text_that_cant_be_a_tmdb_id() {
    for text in ["", "amelie", "-1", "1.5", "4294967296"] {
        assert_eq!(
            ExternalContentId::parse(ContentType::Movie, text),
            None,
            "{text}"
        );
    }
}

#[test]
fn external_content_id_gives_its_type_and_external_id() {
    let external_content_id = ExternalContentId::TvShow(TmdbId::new(2316));

    assert_eq!(
        (
            external_content_id.content_type(),
            external_content_id.external_id()
        ),
        (ContentType::TvShow, "2316".to_owned())
    );
}
