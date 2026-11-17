//! A database of its own for each test, on the Postgres server of `DATABASE_URL`, which the
//! worktrees share. `#[database_test]` gives one to a test. `#[sqlx::test]` names a test's database
//! after the test alone, so the same test run in two worktrees at once would drop the other's
//! database.

use std::{
    io::{self, Write},
    str::FromStr,
    sync::atomic::{AtomicU32, Ordering},
    time::Duration,
};

use anyhow::Context;
use sqlx::{
    AssertSqlSafe, Connection, Executor, PgConnection, PgPool,
    postgres::{PgConnectOptions, PgPoolOptions},
};
use tokio::time;

/// A test's database, with the migrations.
pub struct TestDatabase {
    server: PgConnectOptions,
    name: String,
    pool: PgPool,
}

impl TestDatabase {
    pub async fn create() -> Self {
        static CREATED: AtomicU32 = AtomicU32::new(0);

        let url = std::env::var("DATABASE_URL").expect("DATABASE_URL is set");
        let worktree = PgConnectOptions::from_str(&url).expect("DATABASE_URL is a Postgres URL");
        let server = worktree.clone().database("postgres");
        // Named after the worktree's database, so that its teardown drops those a killed test run
        // left
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

        execute(&server, format!(r#"CREATE DATABASE "{name}""#))
            .await
            .unwrap_or_else(|error| panic!("failed to create the test database {name}: {error}"));
        match migrated_pool(worktree.database(&name)).await {
            Ok(pool) => Self { server, name, pool },
            Err(error) => {
                drop_database(&server, &name).await;
                panic!("failed to set up the test database {name}: {error:#}");
            }
        }
    }

    pub fn pool(&self) -> PgPool {
        self.pool.clone()
    }

    /// Drops the database, and the connections the test left open. Gives up after 10 seconds, so
    /// that a stuck Postgres can't hold back the test's own failure, and only reports a failure,
    /// as the worktree's teardown drops what's left.
    pub async fn drop(self) {
        drop_database(&self.server, &self.name).await;
    }
}

async fn migrated_pool(database: PgConnectOptions) -> anyhow::Result<PgPool> {
    let pool = PgPoolOptions::new()
        // Leaves connections to the other tests and worktrees
        .max_connections(5)
        .connect_with(database)
        .await
        .context("failed to connect")?;
    sqlx::migrate!()
        .run(&pool)
        .await
        .context("failed to run the migrations")?;
    Ok(pool)
}

/// Does `TestDatabase::drop`'s work, also for a database whose setup failed.
async fn drop_database(server: &PgConnectOptions, name: &str) {
    let sql = format!(r#"DROP DATABASE "{name}" WITH (FORCE)"#);
    let failure = match time::timeout(Duration::from_secs(10), execute(server, sql)).await {
        Ok(Ok(())) => return,
        Ok(Err(error)) => error.to_string(),
        Err(_) => "timed out".to_owned(),
    };
    // Unlike `eprintln!`, can't panic and replace the test's own panic
    let _ = writeln!(
        io::stderr(),
        "Couldn't drop the test database {name}: {failure}"
    );
}

async fn execute(server: &PgConnectOptions, sql: String) -> Result<(), sqlx::Error> {
    let mut connection = PgConnection::connect_with(server).await?;
    connection.execute(AssertSqlSafe(sql)).await?;
    connection.close().await
}
