//! Runs the server: reads the environment, connects to the database and serves the app.

use std::{env, net::Ipv4Addr};

use anyhow::Context;
use tokio::{net::TcpListener, signal};

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
    tracing::info!("listening on port {port}");
    axum::serve(listener, watch_club::router(db))
        .with_graceful_shutdown(shutdown_requested())
        .await
        .context("failed to serve")
}

/// Waits for Ctrl-C, or the SIGTERM that `docker stop` sends.
async fn shutdown_requested() {
    let ctrl_c = async {
        signal::ctrl_c().await.expect("Ctrl-C can be listened to");
    };
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("SIGTERM can be listened to")
            .recv()
            .await;
    };
    tokio::select! {
        () = ctrl_c => {},
        () = terminate => {},
    }
}
