//! Runs the server: reads the environment, connects to the database and serves the app.

use std::{env, io, net::Ipv4Addr};

use anyhow::Context;
use tokio::{
    net::TcpListener,
    runtime::Runtime,
    signal::unix::{SignalKind, signal},
};
use watch_club::observability;

fn main() -> anyhow::Result<()> {
    // Before the async runtime, as Sentry needs. Dropped after it, to send what's left
    let observability = observability::start()?;
    let url = env::var("DATABASE_URL").context("failed to read DATABASE_URL")?;
    let port: u16 = env::var("PORT")
        .context("failed to read PORT")?
        .parse()
        .context("PORT isn't a port number")?;
    Runtime::new()
        .context("failed to start the async runtime")?
        .block_on(serve(&url, port, observability.web_sentry_dsn()))
}

/// Serves the app on the port until Ctrl-C or `docker stop`.
async fn serve(url: &str, port: u16, web_sentry_dsn: Option<String>) -> anyhow::Result<()> {
    let db = watch_club::connect_database(url)
        .await
        .context("failed to connect to the database")?;
    observability::observe_pool(&db);
    // On every address, as containers need
    let listener = TcpListener::bind((Ipv4Addr::UNSPECIFIED, port))
        .await
        .with_context(|| format!("failed to listen on port {port}"))?;
    let shutdown = shutdown_requested().context("failed to listen for shutdown signals")?;
    tracing::info!("listening on port {port}");
    axum::serve(listener, watch_club::router(db.clone(), web_sentry_dsn))
        .with_graceful_shutdown(shutdown)
        .await
        .context("failed to serve")?;
    db.close().await;
    Ok(())
}

/// Listens for Ctrl-C and the SIGTERM that `docker stop` sends, and returns a future that waits
/// for either.
fn shutdown_requested() -> io::Result<impl Future<Output = ()>> {
    let mut interrupt = signal(SignalKind::interrupt())?;
    let mut terminate = signal(SignalKind::terminate())?;
    Ok(async move {
        tokio::select! {
            _ = interrupt.recv() => {},
            _ = terminate.recv() => {},
        }
    })
}
