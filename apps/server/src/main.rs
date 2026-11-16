//! Runs the server: reads the environment, connects to the database and serves the app.

use std::{io, net::Ipv4Addr};

use anyhow::Context;
use secrecy::ExposeSecret;
use tokio::{
    net::TcpListener,
    signal::unix::{SignalKind, signal},
};
use watch_club::config::Config;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()),
        )
        .init();

    let config = Config::from_env()?;

    let db = watch_club::connect_database(config.database_url.expose_secret())
        .await
        .context("failed to connect to the database")?;
    // On every address, as containers need
    let listener = TcpListener::bind((Ipv4Addr::UNSPECIFIED, config.port))
        .await
        .with_context(|| format!("failed to listen on port {}", config.port))?;
    let shutdown = shutdown_requested().context("failed to listen for shutdown signals")?;
    tracing::info!("listening on port {}", config.port);
    axum::serve(listener, watch_club::router(db.clone()))
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
