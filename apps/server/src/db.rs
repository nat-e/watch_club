//! The app's Postgres database: the pool of connections to it, which runs the migrations and reports
//! its connections in metrics.

use opentelemetry::{KeyValue, global};
use opentelemetry_semantic_conventions::{
    attribute::{DB_CLIENT_CONNECTION_POOL_NAME, DB_CLIENT_CONNECTION_STATE},
    metric::{DB_CLIENT_CONNECTION_COUNT, DB_CLIENT_CONNECTION_MAX},
};
use sqlx::{PgPool, postgres::PgPoolOptions};

/// Connects to the app's database, runs its pending migrations, and reports the pool's connections
/// in metrics. Call it after `observability::start`, without which the metrics go nowhere.
pub async fn connect(url: &str) -> Result<PgPool, sqlx::Error> {
    let db = PgPoolOptions::new()
        // Shared by the requests and the jobs, which hold one only while a query runs
        .max_connections(10)
        .connect(url)
        .await?;
    sqlx::migrate!().run(&db).await?;
    observe(&db);
    Ok(db)
}

/// Reports the pool's connections in metrics: how many are used and idle, and the most it opens.
fn observe(db: &PgPool) {
    let options = db.connect_options();
    // The name the conventions give a pool that has none
    let pool_name = KeyValue::new(
        DB_CLIENT_CONNECTION_POOL_NAME,
        format!(
            "{}:{}/{}",
            options.get_host(),
            options.get_port(),
            options.get_database().unwrap_or_default(),
        ),
    );
    let meter = global::meter(env!("CARGO_PKG_NAME"));

    let pool = db.clone();
    let name = pool_name.clone();
    meter
        .i64_observable_up_down_counter(DB_CLIENT_CONNECTION_COUNT)
        .with_unit("{connection}")
        .with_description("The connections to the database, by state.")
        .with_callback(move |observer| {
            let size = i64::from(pool.size());
            let idle = i64::try_from(pool.num_idle()).unwrap_or(i64::MAX).min(size);
            for (state, count) in [("idle", idle), ("used", size - idle)] {
                observer.observe(
                    count,
                    &[
                        name.clone(),
                        KeyValue::new(DB_CLIENT_CONNECTION_STATE, state),
                    ],
                );
            }
        })
        .build();

    let max = i64::from(db.options().get_max_connections());
    meter
        .i64_observable_up_down_counter(DB_CLIENT_CONNECTION_MAX)
        .with_unit("{connection}")
        .with_description("The most connections the pool opens to the database.")
        .with_callback(move |observer| observer.observe(max, std::slice::from_ref(&pool_name)))
        .build();
}
