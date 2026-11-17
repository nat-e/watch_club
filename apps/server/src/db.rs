//! The app's Postgres database: the pool of connections to it, which runs the migrations, traces
//! each query and reports its connections in metrics.

use sqlx::{PgPool, Postgres, postgres::PgPoolOptions};
use sqlx_otel::PoolBuilder;

/// The pool of connections to the app's database. Each query gets a span, with OpenTelemetry's
/// database conventions: name it with `.with_operation("SELECT", "users")`, from
/// `sqlx_otel::QueryAnnotateExt`.
pub type Pool = sqlx_otel::Pool<Postgres>;

/// Connects to the app's database, runs its pending migrations, and reports the pool's connections
/// in metrics. Call it after `observability::start`, without which the spans and metrics go
/// nowhere.
pub async fn connect(url: &str) -> Result<Pool, sqlx::Error> {
    let db = PgPoolOptions::new()
        // Shared by the requests and the jobs, which hold one only while a query runs
        .max_connections(10)
        .connect(url)
        .await?;
    sqlx::migrate!().run(&db).await?;
    let options = db.connect_options();
    // The name the conventions give a pool that has none. Naming it turns on the metric of its
    // connections by state
    let name = format!(
        "{}:{}/{}",
        options.get_host(),
        options.get_port(),
        options.get_database().unwrap_or_default(),
    );
    Ok(PoolBuilder::from(db).with_pool_name(name).build())
}

/// Traces the queries of a pool that `connect` didn't open, such as a test's.
pub fn instrument(db: PgPool) -> Pool {
    PoolBuilder::from(db).build()
}
