//! Runs the server: reads the environment, connects to the database, and serves the app and runs
//! its jobs until it's asked to stop.

use std::{io, net::Ipv4Addr, time::Duration};

use anyhow::Context;
use secrecy::ExposeSecret;
use tokio::{
    net::TcpListener,
    runtime::Runtime,
    signal::unix::{SignalKind, signal},
    time,
};
use tokio_util::sync::CancellationToken;
use watch_club::{config::Config, jobs, observability};

fn main() -> anyhow::Result<()> {
    let config = Config::from_env()?;
    // Before the async runtime, as Sentry needs. Dropped after it, to send what's left
    let _observability = observability::start(&config.observability)?;
    Runtime::new()
        .context("failed to start the async runtime")?
        .block_on(serve(config))
}

/// Serves the app and runs its jobs until Ctrl-C or `docker stop`.
async fn serve(config: Config) -> anyhow::Result<()> {
    let db = watch_club::connect_database(config.database_url.expose_secret())
        .await
        .context("failed to connect to the database")?;
    observability::observe_pool(&db);
    // On every address, as containers need
    let listener = TcpListener::bind((Ipv4Addr::UNSPECIFIED, config.port))
        .await
        .with_context(|| format!("failed to listen on port {}", config.port))?;
    let shutdown = CancellationToken::new();
    cancel_on_signals(shutdown.clone()).context("failed to listen for shutdown signals")?;

    let runner = tokio::spawn(jobs::run(db.clone(), shutdown.clone()));
    tracing::info!("listening on port {}", config.port);
    let server = axum::serve(
        listener,
        watch_club::router(db.clone(), config.observability.web_sentry_dsn),
    )
    .with_graceful_shutdown(shutdown.clone().cancelled_owned());
    // Whichever stops first stops the other, so the server exits when the runner fails
    let (serve_result, run_result) = tokio::join!(
        async {
            let serve_result = server.await;
            shutdown.cancel();
            serve_result
        },
        async {
            let run_result = runner.await;
            shutdown.cancel();
            run_result
        },
    );
    serve_result.context("failed to serve")?;
    run_result
        .context("the job runner panicked")?
        .context("the job runner failed")?;
    // Gives up on the connections that a stopped job's query still holds, to exit within the 10 s
    // `docker stop` waits
    let _ = time::timeout(Duration::from_secs(1), db.close()).await;
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
