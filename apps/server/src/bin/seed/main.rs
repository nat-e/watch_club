//! Fills the database with what to try the app with: the Instance Administrator, and the Contents
//! of the dev catalog, saved from their Metadata Providers. Only for development: the primary
//! worktree runs it with `pnpm --filter server seed`, and the other worktrees copy its database.
//! It only adds what's missing, so it can run again, such as after the catalog changes.

mod catalog;

use anyhow::Context;
use secrecy::ExposeSecret;
use watch_club::{
    config::Config,
    db::{self, Pool},
    domain::{
        accounts::{self, CreateInstanceAdministratorError, Locale, Password, Username},
        contents::{self, Hardcover, MetadataProviders, Sportarr, Tmdb},
    },
};

/// The Instance Administrator's username
const USERNAME: &str = "admin";
/// The Instance Administrator's password
const PASSWORD: &str = "passw0rd";

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config = Config::from_env()?;
    let db = db::connect(config.database_url.expose_secret()).await?;

    seed_instance_administrator(&db).await?;
    seed_catalog(&db, &config).await?;
    Ok(())
}

/// Creates the Instance Administrator, unless the database has one.
async fn seed_instance_administrator(db: &Pool) -> anyhow::Result<()> {
    let username = Username::parse(USERNAME).expect("the seed's username follows the rules");
    let password = Password::parse(PASSWORD.into()).expect("the seed's password follows the rules");

    // Signs them in too, on a device nobody uses
    match accounts::create_instance_administrator(db, username, password, Locale::EnUs).await {
        Ok(_) => println!("Sign in as {USERNAME} with the password \"{PASSWORD}\""),
        Err(CreateInstanceAdministratorError::AlreadyExists) => {
            println!("The database already has its Instance Administrator");
        }
        Err(error) => return Err(error.into()),
    }
    Ok(())
}

/// Saves the dev catalog's Contents that aren't saved yet, from their Metadata Providers. Fails on
/// the first that can't be saved, such as without the internet.
async fn seed_catalog(db: &Pool, config: &Config) -> anyhow::Result<()> {
    let metadata_providers = MetadataProviders {
        tmdb: Tmdb::new(&config.tmdb_api_token)?,
        sportarr: Sportarr::new()?,
        hardcover: Hardcover::new(&config.hardcover_api_token)?,
    };

    let external_content_ids = catalog::external_content_ids();
    for external_content_id in &external_content_ids {
        contents::get_by_external_id(
            db,
            &metadata_providers,
            external_content_id.clone(),
            Locale::EnUs,
        )
        .await
        .with_context(|| format!("failed to save the dev catalog's {external_content_id:?}"))?;
    }
    println!(
        "The database has the dev catalog's {} Contents",
        external_content_ids.len()
    );
    Ok(())
}
