//! A database of its own for each test, on the Postgres server of `DATABASE_URL`, which the
//! worktrees share. `#[database_test]` gives one to a test. `#[sqlx::test]` names a test's database
//! after the test alone, so the same test run in two worktrees at once would drop the other's
//! database.

use std::{
    str::FromStr,
    sync::atomic::{AtomicU32, Ordering},
};

use sqlx::{
    AssertSqlSafe, Connection, Executor, PgConnection, PgPool,
    postgres::{PgConnectOptions, PgPoolOptions},
};

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

        execute(&server, format!(r#"CREATE DATABASE "{name}""#)).await;
        let pool = PgPoolOptions::new()
            // Leaves connections to the other tests and worktrees
            .max_connections(5)
            .connect_with(worktree.database(&name))
            .await
            .expect("connects to the test database");
        sqlx::migrate!()
            .run(&pool)
            .await
            .expect("runs the migrations");
        Self { server, name, pool }
    }

    pub fn pool(&self) -> PgPool {
        self.pool.clone()
    }

    /// Drops the database, and the connections the test left open.
    pub async fn drop(self) {
        execute(
            &self.server,
            format!(r#"DROP DATABASE "{}" WITH (FORCE)"#, self.name),
        )
        .await;
    }
}

async fn execute(server: &PgConnectOptions, sql: String) {
    let mut connection = PgConnection::connect_with(server)
        .await
        .expect("connects to Postgres");
    connection
        .execute(AssertSqlSafe(sql))
        .await
        .expect("creates or drops the test database");
    connection.close().await.expect("disconnects");
}
