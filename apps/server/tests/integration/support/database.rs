//! A database of its own for each test, on the Postgres server of `DATABASE_URL`, which the
//! worktrees share. `#[database_test]` gives one to a test. `#[sqlx::test]` names a test's database
//! after the test alone, so the same test run in two worktrees at once would drop the other's
//! database.

use std::{
    io::{self, Write},
    str::FromStr,
    sync::atomic::{AtomicU32, Ordering},
    thread,
    time::Duration,
};

use anyhow::Context;
use sqlx::{
    AssertSqlSafe, Connection, Executor, PgConnection, PgPool,
    postgres::{PgConnectOptions, PgPoolOptions},
};

/// Creates a database with the migrations for one test, and returns a pool on it. The database is
/// dropped with the pool, once the test has dropped every clone of it.
pub async fn database() -> PgPool {
    // Leaves connections to the other tests and worktrees
    create(PgPoolOptions::new().max_connections(5)).await
}

/// Creates a database like `database`, with a pool of a single connection, for code that must not
/// need a second one: waiting for it fails after 2 seconds rather than hanging.
pub async fn database_with_one_connection() -> PgPool {
    create(
        PgPoolOptions::new()
            .max_connections(1)
            .acquire_timeout(Duration::from_secs(2)),
    )
    .await
}

async fn create(options: PgPoolOptions) -> PgPool {
    static CREATED: AtomicU32 = AtomicU32::new(0);

    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL is set");
    let worktree = PgConnectOptions::from_str(&url).expect("DATABASE_URL is a Postgres URL");
    let server = worktree.clone().database("postgres");
    // Named after the worktree's database, so that its teardown drops those a killed test run left
    let name = format!(
        "{}-test-{}-{}",
        worktree
            .get_database()
            .expect("DATABASE_URL names a database"),
        std::process::id(),
        CREATED.fetch_add(1, Ordering::Relaxed),
    );
    // Postgres would cut a longer name, and give two tests the same database
    assert!(name.len() <= 63, "{name} is longer than 63 bytes");

    let mut connection = PgConnection::connect_with(&server)
        .await
        .expect("connects to Postgres");
    connection
        .execute(AssertSqlSafe(format!(r#"CREATE DATABASE "{name}""#)))
        .await
        .expect("creates the test database");
    connection.close().await.expect("disconnects");

    let test_database = TestDatabase {
        server,
        name: name.clone(),
    };
    let db = options
        // Only holds `test_database`: the pool drops this callback, and so the database, with it
        .after_connect(move |_, _| {
            let _test_database = &test_database;
            Box::pin(async { Ok(()) })
        })
        .connect_with(worktree.database(&name))
        .await
        .expect("connects to the test database");
    sqlx::migrate!()
        .run(&db)
        .await
        .expect("runs the migrations");
    db
}

/// A test's database, which is dropped with this.
struct TestDatabase {
    server: PgConnectOptions,
    name: String,
}

impl Drop for TestDatabase {
    fn drop(&mut self) {
        let (server, name) = (self.server.clone(), self.name.clone());
        // `drop` can't await, and runs in the test's runtime or after it has stopped: a thread with
        // its own runtime works in both cases
        let dropped = thread::Builder::new()
            .spawn(move || {
                tokio::runtime::Builder::new_current_thread()
                    .enable_all()
                    .build()?
                    .block_on(async {
                        tokio::time::timeout(Duration::from_secs(10), drop_database(server, name))
                            .await
                            .context("timed out")?
                    })
            })
            .context("failed to start a thread")
            .and_then(|thread| {
                thread
                    .join()
                    .unwrap_or_else(|_| Err(anyhow::anyhow!("panicked")))
            });
        // Only reports the failure: a panic while a failed test unwinds would abort the tests
        if let Err(error) = dropped {
            let _ = writeln!(
                io::stderr(),
                "Couldn't drop the test database {}: {error:#}",
                self.name
            );
        }
    }
}

async fn drop_database(server: PgConnectOptions, name: String) -> anyhow::Result<()> {
    let mut connection = PgConnection::connect_with(&server).await?;
    // Also closes the connections the pool still has open
    connection
        .execute(AssertSqlSafe(format!(
            r#"DROP DATABASE "{name}" WITH (FORCE)"#
        )))
        .await?;
    connection.close().await?;
    Ok(())
}
