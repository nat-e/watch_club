//! Runs the server: reads the environment, connects to the database, and serves the app and runs
//! its jobs until it's asked to stop.

use std::{io, net::Ipv4Addr};

use anyhow::Context;
use secrecy::ExposeSecret;
use tokio::{
    net::TcpListener,
    signal::unix::{SignalKind, signal},
};
use tokio_util::sync::CancellationToken;
use watch_club::{config::Config, jobs};

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
    let shutdown = CancellationToken::new();
    cancel_on_signals(shutdown.clone()).context("failed to listen for shutdown signals")?;

    let runner = tokio::spawn(jobs::run(db.clone(), shutdown.clone()));
    tracing::info!("listening on port {}", config.port);
    let app = axum::serve(listener, watch_club::router(db.clone()))
        .with_graceful_shutdown(shutdown.clone().cancelled_owned());
    // Whichever stops first stops the other, so the server exits when the runner fails
    let (served, ran) = tokio::join!(
        async {
            let served = app.await;
            shutdown.cancel();
            served
        },
        async {
            let ran = runner.await;
            shutdown.cancel();
            ran
        },
    );
    served.context("failed to serve")?;
    ran.context("the job runner panicked")?
        .context("the job runner failed")?;
    db.close().await;
    Ok(())
}

/// Cancels `shutdown` on Ctrl-C or on the SIGTERM that `docker stop` sends.
fn cancel_on_signals(shutdown: CancellationToken) -> io::Result<()> {
    let mut interrupt = signal(SignalKind::interrupt())?;
    let mut terminate = signal(SignalKind::terminate())?;
    tokio::spawn(async move {
        tokio::select! {
            _ = interrupt.recv() => {},
            _ = terminate.recv() => {},
        }
        shutdown.cancel();
    });
    Ok(())
}
