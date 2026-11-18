//! Runs the server: reads the environment, connects to the database, and serves the app and runs
//! its jobs until it's asked to stop.

use std::{io, net::Ipv4Addr, sync::Arc, time::Duration};

use anyhow::Context;
use secrecy::ExposeSecret;
use tokio::{
    net::TcpListener,
    runtime::Runtime,
    signal::unix::{SignalKind, signal},
    time,
};
use tokio_util::sync::CancellationToken;
use tracing::Level;
use watch_club::{
    AppState, AppsSentry, config::Config, db, integrations::tmdb, jobs, observability,
};

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
    let db = db::connect(config.database_url.expose_secret())
        .await
        .context("failed to connect to the database")?;
    // On every address, as containers need
    let listener = TcpListener::bind((Ipv4Addr::UNSPECIFIED, config.port))
        .await
        .with_context(|| format!("failed to listen on port {}", config.port))?;
    let tmdb = tmdb::Client::new(&config.tmdb_api_token)?;
    let shutdown = CancellationToken::new();
    cancel_on_signals(shutdown.clone()).context("failed to listen for shutdown signals")?;

    let runner = tokio::spawn(jobs::run(db.clone(), shutdown.clone()));
    tracing::event!(
        name: "server.started",
        Level::INFO,
        service.version = %env!("CARGO_PKG_VERSION"),
        server.port = config.port,
        "listening for requests",
    );
    let server = axum::serve(
        listener,
        watch_club::router(AppState {
            db: db.clone(),
            apps_sentry: AppsSentry {
                web_dsn: config.observability.web_sentry_dsn.map(Arc::from),
                mobile_dsn: config.observability.mobile_sentry_dsn.map(Arc::from),
                environment: config.observability.sentry_environment.into(),
            },
            tmdb,
        }),
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
    tracing::event!(name: "server.stopped", Level::INFO, "stopped");
    Ok(())
}

/// Cancels `shutdown` on Ctrl-C or on the SIGTERM that `docker stop` sends.
fn cancel_on_signals(shutdown: CancellationToken) -> io::Result<()> {
    let mut interrupt = signal(SignalKind::interrupt())?;
    let mut terminate = signal(SignalKind::terminate())?;
    tokio::spawn(async move {
        let signal = tokio::select! {
            _ = interrupt.recv() => "SIGINT",
            _ = terminate.recv() => "SIGTERM",
        };
        tracing::event!(
            name: "server.stopping",
            Level::INFO,
            signal = %signal,
            "stopping once the requests and jobs in progress end",
        );
        shutdown.cancel();
    });
    Ok(())
}
