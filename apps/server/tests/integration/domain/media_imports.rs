//! Media Imports, through `domain::media_imports` and the jobs that run them: the files of Radarr
//! Sources, matched to their Movie on a fake TMDB.

use serde_json::{Value, json};
use sqlx::PgPool;
use watch_club::{
    db::Pool,
    domain::{
        contents::metadata::MetadataProviders,
        media_imports::{
            self, FilesToImport, MediaImport, MediaImportFailure, MediaImportState,
            MediaImportTrigger, StartMediaImportError,
        },
        sources::{self, SourceId},
    },
    jobs,
    utils::filesystem::AbsoluteFolder,
};
use watch_club_test_macros::database_test;
use wiremock::{
    Mock, ResponseTemplate,
    matchers::{method, path, query_param},
};

use crate::support::{
    self, FakeServarr, FakeTmdb,
    fake_servarr::radarr_movie,
    fake_tmdb::{MOVIE_ID, fixture},
};

/// The IMDb ID of the Movie of `fixtures/tmdb`, Amélie
const MOVIE_IMDB_ID: &str = "tt0211915";

/// A TMDB ID that the fake TMDB doesn't know
const UNKNOWN_MOVIE_ID: u32 = 999_999;

/// Where the fake Radarr has the file of the Movie of `fixtures/tmdb`
const MOVIE_PATH: &str = "/movies/Amélie (2001)/Amélie (2001).mkv";

/// Where the fake Radarr has the file of a Movie that the fake TMDB doesn't know
const UNKNOWN_MOVIE_PATH: &str = "/movies/Unknown (2001)/Unknown (2001).mkv";

/// A folder that exists wherever the tests run
const FOLDER: &str = env!("CARGO_MANIFEST_DIR");

/// Creates a Source of the fake app, which sees its files at the paths the app gives.
async fn create_source(db: &Pool, app: &FakeServarr) -> SourceId {
    sources::servarr::create(
        db,
        &support::encryption_key(),
        app.app(),
        app.source_configuration(),
        &app.api_key(),
    )
    .await
    .unwrap()
    .id()
}

/// Imports these files of the Source, as the Instance Administrator does, and returns the import
/// once its job ran.
async fn import(
    db: &Pool,
    metadata_providers: MetadataProviders,
    source_id: SourceId,
    files_to_import: FilesToImport,
) -> MediaImport {
    let started = media_imports::start(db, source_id, files_to_import)
        .await
        .unwrap();
    let context = support::job_context_with_metadata_providers(db, metadata_providers);
    jobs::run_available(&context).await.unwrap();

    media_imports::list(db, source_id)
        .await
        .unwrap()
        .into_iter()
        .find(|media_import| media_import.id == started.id)
        .unwrap()
}

/// Returns the Source's Media Files, by path, with the TMDB ID of the Movie whose Part 1 each
/// holds, or None for an Unmatched file.
async fn saved_files(db: &Pool, source_id: SourceId) -> Vec<(String, Option<String>)> {
    sqlx::query!(
        r#"
        SELECT f.path, c.main_external_id AS "tmdb_id?"
        FROM media_files f
        LEFT JOIN media_file_parts fp ON fp.media_file_id = f.id
        LEFT JOIN media_parts p ON p.id = fp.media_part_id AND p.number = 1
        LEFT JOIN media m ON m.id = p.media_id
        LEFT JOIN contents c ON c.id = m.content_id
        WHERE f.source_id = $1
        ORDER BY f.path
        "#,
        source_id as SourceId,
    )
    .fetch_all(db)
    .await
    .unwrap()
    .into_iter()
    .map(|file| (file.path, file.tmdb_id))
    .collect()
}

/// Returns the counts of the import: the files it handles, and those it matched, saved as
/// Unmatched, failed, and removed.
fn counts(media_import: &MediaImport) -> (Option<i32>, i32, i32, i32, i32) {
    (
        media_import.file_count,
        media_import.matched_file_count,
        media_import.unmatched_file_count,
        media_import.failed_file_count,
        media_import.removed_file_count,
    )
}

/// Returns a fake Radarr that lists these Movies.
async fn radarr_with(movies: Value) -> FakeServarr {
    let radarr = FakeServarr::radarr().await;
    radarr.answer_movies(movies).await;
    radarr
}

/// Returns a fake TMDB that knows the Movie of `fixtures/tmdb` only.
async fn tmdb_with_the_fixtures() -> FakeTmdb {
    let tmdb = FakeTmdb::start().await;
    tmdb.answer_fixtures().await;
    tmdb
}

#[database_test]
async fn matches_each_file_to_part_1_of_its_movie_saved_from_tmdb(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = radarr_with(json!([radarr_movie(
        MOVIE_ID,
        MOVIE_IMDB_ID,
        Some(MOVIE_PATH)
    )]))
    .await;
    let tmdb = tmdb_with_the_fixtures().await;
    let source_id = create_source(&db, &radarr).await;

    let media_import = import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::All,
    )
    .await;

    assert_eq!(media_import.state, MediaImportState::Completed);
    assert_eq!(media_import.trigger, MediaImportTrigger::Manual);
    assert_eq!(media_import.failure, None);
    assert!(media_import.finished_at.is_some());
    assert_eq!(counts(&media_import), (Some(1), 1, 0, 0, 0));
    assert_eq!(
        saved_files(&db, source_id).await,
        [(MOVIE_PATH.to_owned(), Some(MOVIE_ID.to_string()))]
    );
}

#[database_test]
async fn saves_the_files_tmdb_doesnt_know_as_unmatched(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = radarr_with(json!([radarr_movie(
        UNKNOWN_MOVIE_ID,
        "",
        Some(UNKNOWN_MOVIE_PATH)
    )]))
    .await;
    // Answers 404 to every request
    let tmdb = FakeTmdb::start().await;
    let source_id = create_source(&db, &radarr).await;

    let media_import = import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::All,
    )
    .await;

    assert_eq!(media_import.state, MediaImportState::Completed);
    assert_eq!(counts(&media_import), (Some(1), 0, 1, 0, 0));
    assert_eq!(
        saved_files(&db, source_id).await,
        [(UNKNOWN_MOVIE_PATH.to_owned(), None)]
    );
}

#[database_test]
async fn finds_a_movie_by_its_imdb_id_when_tmdb_no_longer_knows_its_tmdb_id(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = radarr_with(json!([radarr_movie(
        UNKNOWN_MOVIE_ID,
        MOVIE_IMDB_ID,
        Some(MOVIE_PATH)
    )]))
    .await;
    let tmdb = tmdb_with_the_fixtures().await;
    Mock::given(method("GET"))
        .and(path(format!("/find/{MOVIE_IMDB_ID}")))
        .and(query_param("external_source", "imdb_id"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "movie_results": [{ "id": MOVIE_ID }],
            "tv_results": [],
        })))
        .mount(&tmdb.server)
        .await;
    let source_id = create_source(&db, &radarr).await;

    let media_import = import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::All,
    )
    .await;

    assert_eq!(counts(&media_import), (Some(1), 1, 0, 0, 0));
    assert_eq!(
        saved_files(&db, source_id).await,
        [(MOVIE_PATH.to_owned(), Some(MOVIE_ID.to_string()))]
    );
}

#[database_test]
async fn counts_the_files_of_a_movie_tmdb_fails_on_as_failed_and_goes_on(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let failing_path = "/movies/Failing (2001)/Failing (2001).mkv";
    let radarr = radarr_with(json!([
        radarr_movie(500, "", Some(failing_path)),
        radarr_movie(MOVIE_ID, MOVIE_IMDB_ID, Some(MOVIE_PATH)),
    ]))
    .await;
    let tmdb = tmdb_with_the_fixtures().await;
    Mock::given(method("GET"))
        .and(path("/movie/500"))
        .respond_with(ResponseTemplate::new(500))
        .mount(&tmdb.server)
        .await;
    let source_id = create_source(&db, &radarr).await;

    let media_import = import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::All,
    )
    .await;

    assert_eq!(media_import.state, MediaImportState::Completed);
    assert_eq!(counts(&media_import), (Some(2), 1, 0, 1, 0));
    // The failed file isn't saved, so the next import tries it again
    assert_eq!(
        saved_files(&db, source_id).await,
        [(MOVIE_PATH.to_owned(), Some(MOVIE_ID.to_string()))]
    );
}

#[database_test]
async fn saves_each_movie_from_tmdb_once_for_all_its_copies(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let copy_path = "/movies/Amélie (2001)/Amélie (2001) - 4K.mkv";
    let radarr = radarr_with(json!([
        radarr_movie(MOVIE_ID, MOVIE_IMDB_ID, Some(MOVIE_PATH)),
        radarr_movie(MOVIE_ID, MOVIE_IMDB_ID, Some(copy_path)),
    ]))
    .await;
    let tmdb = FakeTmdb::start().await;
    Mock::given(method("GET"))
        .and(path(format!("/movie/{MOVIE_ID}")))
        .respond_with(ResponseTemplate::new(200).set_body_json(fixture("movie_details")))
        .expect(1)
        .mount(&tmdb.server)
        .await;
    let source_id = create_source(&db, &radarr).await;

    let media_import = import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::All,
    )
    .await;

    assert_eq!(counts(&media_import), (Some(2), 2, 0, 0, 0));
    let movie = Some(MOVIE_ID.to_string());
    assert_eq!(
        saved_files(&db, source_id).await,
        [
            (copy_path.to_owned(), movie.clone()),
            (MOVIE_PATH.to_owned(), movie),
        ]
    );
}

#[database_test]
async fn imports_only_the_movies_with_a_file_in_the_root_folder_on_the_quality_profile(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let mut other_profile = radarr_movie(2, "", Some("/movies/Two/Two.mkv"));
    other_profile["qualityProfileId"] = json!(1);
    let radarr = radarr_with(json!([
        radarr_movie(MOVIE_ID, MOVIE_IMDB_ID, Some(MOVIE_PATH)),
        other_profile,
        radarr_movie(3, "", Some("/movies-4k/Three/Three.mkv")),
        radarr_movie(4, "", None),
    ]))
    .await;
    let tmdb = tmdb_with_the_fixtures().await;
    let source_id = create_source(&db, &radarr).await;

    let media_import = import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::All,
    )
    .await;

    assert_eq!(counts(&media_import), (Some(1), 1, 0, 0, 0));
    assert_eq!(saved_files(&db, source_id).await.len(), 1);
}

#[database_test]
async fn saves_the_files_where_watch_club_sees_the_root_folder(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = radarr_with(json!([radarr_movie(
        MOVIE_ID,
        MOVIE_IMDB_ID,
        Some(MOVIE_PATH)
    )]))
    .await;
    let tmdb = tmdb_with_the_fixtures().await;
    let mut configuration = radarr.source_configuration();
    configuration.local_root_folder_path = Some(AbsoluteFolder::parse(FOLDER).await.unwrap());
    let source_id = sources::servarr::create(
        &db,
        &support::encryption_key(),
        radarr.app(),
        configuration,
        &radarr.api_key(),
    )
    .await
    .unwrap()
    .id();

    import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::All,
    )
    .await;

    assert_eq!(
        saved_files(&db, source_id).await,
        [(
            format!("{FOLDER}/Amélie (2001)/Amélie (2001).mkv"),
            Some(MOVIE_ID.to_string())
        )]
    );
}

#[database_test]
async fn handles_the_files_that_its_choice_includes(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = radarr_with(json!([
        radarr_movie(MOVIE_ID, MOVIE_IMDB_ID, Some(MOVIE_PATH)),
        radarr_movie(UNKNOWN_MOVIE_ID, "", Some(UNKNOWN_MOVIE_PATH)),
    ]))
    .await;
    let tmdb = tmdb_with_the_fixtures().await;
    let source_id = create_source(&db, &radarr).await;
    let first = import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::New,
    )
    .await;

    let mut handled = Vec::new();
    for files_to_import in [
        FilesToImport::New,
        FilesToImport::NewAndUnmatched,
        FilesToImport::All,
    ] {
        let media_import = import(&db, tmdb.metadata_providers(), source_id, files_to_import).await;
        handled.push(counts(&media_import));
    }

    assert_eq!(counts(&first), (Some(2), 1, 1, 0, 0));
    assert_eq!(
        handled,
        [
            (Some(0), 0, 0, 0, 0),
            (Some(1), 0, 1, 0, 0),
            (Some(2), 1, 1, 0, 0),
        ]
    );
}

#[database_test]
async fn removes_the_files_radarr_no_longer_lists(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = radarr_with(json!([
        radarr_movie(MOVIE_ID, MOVIE_IMDB_ID, Some(MOVIE_PATH)),
        radarr_movie(UNKNOWN_MOVIE_ID, "", Some(UNKNOWN_MOVIE_PATH)),
    ]))
    .await;
    let tmdb = tmdb_with_the_fixtures().await;
    let source_id = create_source(&db, &radarr).await;
    import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::All,
    )
    .await;
    radarr.server.reset().await;
    radarr
        .answer_movies(json!([radarr_movie(
            MOVIE_ID,
            MOVIE_IMDB_ID,
            Some(MOVIE_PATH)
        )]))
        .await;

    let media_import = import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::New,
    )
    .await;

    assert_eq!(counts(&media_import), (Some(0), 0, 0, 0, 1));
    assert_eq!(
        saved_files(&db, source_id).await,
        [(MOVIE_PATH.to_owned(), Some(MOVIE_ID.to_string()))]
    );
}

#[database_test]
async fn fails_without_removing_anything_when_radarr_refuses_the_api_key(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = radarr_with(json!([radarr_movie(
        MOVIE_ID,
        MOVIE_IMDB_ID,
        Some(MOVIE_PATH)
    )]))
    .await;
    let tmdb = tmdb_with_the_fixtures().await;
    let source_id = create_source(&db, &radarr).await;
    import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::All,
    )
    .await;
    sources::servarr::update(
        &db,
        &support::encryption_key(),
        source_id,
        radarr.source_configuration(),
        Some(&"another-api-key".into()),
    )
    .await
    .unwrap();

    let media_import = import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::All,
    )
    .await;

    assert_eq!(media_import.state, MediaImportState::Failed);
    assert_eq!(
        media_import.failure,
        Some(MediaImportFailure::InvalidApiKey)
    );
    assert_eq!(counts(&media_import), (None, 0, 0, 0, 0));
    assert_eq!(saved_files(&db, source_id).await.len(), 1);
}

#[database_test]
async fn start_refuses_a_source_that_doesnt_import_or_doesnt_exist(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let sonarr = FakeServarr::sonarr().await;
    let sonarr_source = create_source(&db, &sonarr).await;
    let radarr = FakeServarr::radarr().await;
    let deleted = create_source(&db, &radarr).await;
    sources::delete(&db, deleted).await.unwrap();

    let unsupported = media_imports::start(&db, sonarr_source, FilesToImport::All).await;
    let missing = media_imports::start(&db, deleted, FilesToImport::All).await;

    assert!(
        matches!(
            unsupported,
            Err(StartMediaImportError::UnsupportedSourceType)
        ),
        "{unsupported:?}"
    );
    assert!(
        matches!(missing, Err(StartMediaImportError::NotFound)),
        "{missing:?}"
    );
}

#[database_test]
async fn start_scheduled_imports_the_new_and_unmatched_files_of_each_radarr_source(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let sonarr = FakeServarr::sonarr().await;
    let radarr_source = create_source(&db, &radarr).await;
    let sonarr_source = create_source(&db, &sonarr).await;

    media_imports::start_scheduled(&db).await.unwrap();

    let radarr_imports = media_imports::list(&db, radarr_source).await.unwrap();
    assert_eq!(radarr_imports.len(), 1);
    assert_eq!(radarr_imports[0].trigger, MediaImportTrigger::Scheduled);
    assert_eq!(
        radarr_imports[0].files_to_import,
        FilesToImport::NewAndUnmatched
    );
    assert_eq!(radarr_imports[0].state, MediaImportState::Waiting);
    assert_eq!(media_imports::list(&db, sonarr_source).await.unwrap(), []);
    let queued =
        sqlx::query_scalar!(r#"SELECT count(*) AS "count!" FROM jobs WHERE kind = 'import_media'"#)
            .fetch_one(&db)
            .await
            .unwrap();
    assert_eq!(queued, 1);
}

#[database_test]
async fn start_scheduled_marks_the_imports_a_stopped_server_left_running_as_interrupted(
    db: PgPool,
) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let source_id = create_source(&db, &radarr).await;
    for job_started in ["2 hours", "10 minutes"] {
        sqlx::query!(
            r#"
            INSERT INTO media_imports (source_id, trigger, files_to_import, state, job_started_at)
            VALUES ($1, 'manual', 'all', 'running', now() - $2::text::interval)
            "#,
            source_id as SourceId,
            job_started,
        )
        .execute(&db)
        .await
        .unwrap();
    }

    media_imports::start_scheduled(&db).await.unwrap();

    let states: Vec<_> = media_imports::list(&db, source_id)
        .await
        .unwrap()
        .into_iter()
        .map(|media_import| (media_import.state, media_import.failure))
        .collect();
    assert_eq!(
        states,
        [
            (MediaImportState::Waiting, None),
            (MediaImportState::Running, None),
            (
                MediaImportState::Failed,
                Some(MediaImportFailure::Interrupted)
            ),
        ]
    );
}

#[database_test]
async fn delete_old_deletes_the_imports_that_finished_over_30_days_ago(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = FakeServarr::radarr().await;
    let source_id = create_source(&db, &radarr).await;
    for (state, started, finished) in [
        ("completed", "31 days", Some("31 days")),
        ("completed", "29 days", Some("29 days")),
        ("running", "40 days", None),
    ] {
        sqlx::query!(
            r#"
            INSERT INTO media_imports (
                source_id, trigger, files_to_import, state, started_at, finished_at
            )
            VALUES (
                $1, 'scheduled', 'new', $2::text::media_import_state, now() - $3::text::interval,
                now() - $4::text::interval
            )
            "#,
            source_id as SourceId,
            state,
            started,
            finished,
        )
        .execute(&db)
        .await
        .unwrap();
    }

    let deleted = media_imports::delete_old(&db).await.unwrap();

    assert_eq!(deleted, 1);
    assert_eq!(media_imports::list(&db, source_id).await.unwrap().len(), 2);
}

#[database_test]
async fn deleting_a_source_deletes_its_files_and_imports(db: PgPool) {
    let db = watch_club::db::instrument(db);
    let radarr = radarr_with(json!([radarr_movie(
        MOVIE_ID,
        MOVIE_IMDB_ID,
        Some(MOVIE_PATH)
    )]))
    .await;
    let tmdb = tmdb_with_the_fixtures().await;
    let source_id = create_source(&db, &radarr).await;
    import(
        &db,
        tmdb.metadata_providers(),
        source_id,
        FilesToImport::All,
    )
    .await;

    sources::delete(&db, source_id).await.unwrap();

    assert_eq!(saved_files(&db, source_id).await, []);
    assert_eq!(media_imports::list(&db, source_id).await.unwrap(), []);
}
