//! A database of its own for each test, on the Postgres server of `DATABASE_URL`, which the
//! worktrees share. `#[sqlx::test]` names a test's database after the test alone, so the same test
//! run in two worktrees at once would drop the other's database.

use std::{
    str::FromStr,
    sync::atomic::{AtomicU32, Ordering},
    thread,
};

use sqlx::{
    AssertSqlSafe, Connection, Executor, PgConnection, PgPool,
    postgres::{PgConnectOptions, PgPoolOptions},
};

/// Creates a database with the migrations for one test, and returns a pool on it. The database is
/// dropped with the pool, once the test has dropped every clone of it.
pub async fn database() -> PgPool {
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

    let drop_database = DropDatabase {
        server,
        name: name.clone(),
    };
    let db = PgPoolOptions::new()
        // Leaves connections to the other tests and worktrees
        .max_connections(5)
        // Only holds `drop_database`: the pool drops this callback, and so the database, with it
        .after_connect(move |_, _| {
            let _drop_database = &drop_database;
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

/// A test's database, which this drops when it's dropped.
struct DropDatabase {
    server: PgConnectOptions,
    name: String,
}

impl Drop for DropDatabase {
    fn drop(&mut self) {
        let server = self.server.clone();
        // Also closes the connections the pool still has open
        let sql = format!(r#"DROP DATABASE "{}" WITH (FORCE)"#, self.name);
        // `drop` can't await, and runs in the test's runtime or after it has stopped: a thread with
        // its own runtime works in both cases
        let dropped = thread::spawn(move || -> anyhow::Result<()> {
            tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()?
                .block_on(async {
                    let mut connection = PgConnection::connect_with(&server).await?;
                    connection.execute(AssertSqlSafe(sql)).await?;
                    connection.close().await?;
                    Ok(())
                })
        })
        .join();
        // Only reports the failure: a panic while a failed test unwinds would abort the tests
        if let Ok(Err(error)) = dropped {
            eprintln!("Couldn't drop the test database {}: {error:#}", self.name);
        }
    }
}
