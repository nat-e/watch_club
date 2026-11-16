//! Runs the server: reads the environment, connects to the database and serves the app.

use std::{env, io, net::Ipv4Addr};

use anyhow::Context;
use tokio::{
    net::TcpListener,
    signal::unix::{SignalKind, signal},
};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()),
        )
        .init();

    let url = env::var("DATABASE_URL").context("failed to read DATABASE_URL")?;
    let port: u16 = env::var("PORT")
        .context("failed to read PORT")?
        .parse()
        .context("PORT isn't a port number")?;

    let db = watch_club::connect_database(&url)
        .await
        .context("failed to connect to the database")?;
    // On every address, as containers need
    let listener = TcpListener::bind((Ipv4Addr::UNSPECIFIED, port))
        .await
        .with_context(|| format!("failed to listen on port {port}"))?;
    let shutdown = shutdown_requested().context("failed to listen for shutdown signals")?;
    tracing::info!("listening on port {port}");
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
