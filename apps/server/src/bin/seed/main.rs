//! Fills the database with what to try the app with: the Instance Administrator, and the dev
//! catalog's Contents, saved from their Metadata Providers, and the Sources of its Radarr, Sonarr
//! and Sportarr, with an import of the files of those that import. Only for development: the
//! primary worktree runs it with
//! `pnpm --filter server seed`, and the other worktrees copy its database. It only adds what's
//! missing, so it can run again, such as after the catalog changes.

mod catalog;

use std::{path::PathBuf, process::Command};

use anyhow::Context;
use secrecy::{ExposeSecret, SecretString};
use watch_club::{
    api_client::HttpClient,
    config::Config,
    db::{self, Pool},
    domain::{
        accounts::{
            instance_administrator::{self, CreateInstanceAdministratorError},
            preferences::Locale,
            users::{Password, Username},
        },
        contents::{self, metadata::MetadataProviders},
        media_imports::{self, FilesToImport, StartMediaImportError},
        sources::{
            self, SourceType,
            servarr::{self, ServarrConfiguration},
        },
    },
    utils::filesystem::AbsoluteFolder,
};

/// The Instance Administrator's username
const USERNAME: &str = "admin";
/// The Instance Administrator's password
const PASSWORD: &str = "passw0rd";

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let config = Config::from_env()?;
    let db = db::connect(config.database_url.expose_secret()).await?;
    let http_client = HttpClient::new()?;

    seed_instance_administrator(&db).await?;
    // Before the Contents, which need the internet
    seed_catalog_sources(&db, &config, &http_client).await?;
    seed_catalog(&db, &config, &http_client).await?;
    Ok(())
}

/// Creates the Instance Administrator, unless the database has one.
async fn seed_instance_administrator(db: &Pool) -> anyhow::Result<()> {
    let username = Username::parse(USERNAME).expect("the seed's username follows the rules");
    let password = Password::parse(PASSWORD.into()).expect("the seed's password follows the rules");

    // Signs them in too, on a device nobody uses
    match instance_administrator::create(db, username, password, Locale::EnUs).await {
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
async fn seed_catalog(db: &Pool, config: &Config, http_client: &HttpClient) -> anyhow::Result<()> {
    let metadata_providers = MetadataProviders::new(
        http_client,
        &config.tmdb_api_token,
        &config.hardcover_api_token,
    )?;

    let external_content_ids = catalog::external_content_ids();
    for external_content_id in &external_content_ids {
        contents::get_by_external_id(
            db,
            &metadata_providers,
            external_content_id.clone(),
            Locale::EnUs,
        )
        .await
        .with_context(|| format!("failed to save the dev catalog's {external_content_id:?}"))?
        .with_context(|| {
            format!(
                "the Metadata Provider of the dev catalog's {external_content_id:?} doesn't know it"
            )
        })?;
    }
    println!(
        "The database has the dev catalog's {} Contents",
        external_content_ids.len()
    );
    Ok(())
}

/// Adds a Source for each of the dev catalog's apps, unless the database has a Source of that app,
/// and queues an import of its files, which the server runs. Skips the apps that don't run.
async fn seed_catalog_sources(
    db: &Pool,
    config: &Config,
    http_client: &HttpClient,
) -> anyhow::Result<()> {
    let existing_sources = sources::list(db).await?;
    // The catalog is in the primary worktree, which every worktree shares
    let primary_worktree = primary_worktree()?;

    for source in catalog::SOURCES {
        let name = source.app.name();
        let has_source_of_app = existing_sources
            .iter()
            .any(|existing| existing.source_type() == SourceType::from(source.app));
        if has_source_of_app {
            println!("The database already has a {name} Source");
            continue;
        }

        // Tests the connection first, as the form does, which also skips the apps that don't run
        let api_key = SecretString::from(source.api_key);
        let choices = match servarr::test_connection(http_client, source.app, source.url, &api_key)
            .await
        {
            Ok(choices) => choices,
            Err(error) => {
                println!(
                    "The dev catalog's {name} wasn't added, as {error}. Run `pnpm catalog`, then seed again"
                );
                continue;
            }
        };
        let quality_profile = choices
            .quality_profiles
            .into_iter()
            .find(|profile| profile.id == source.quality_profile_id)
            .with_context(|| {
                format!(
                    "the dev catalog's {name} has no quality profile {}",
                    source.quality_profile_id
                )
            })?;

        let local_root_folder = primary_worktree.join(source.local_root_folder);
        let local_root_folder = match AbsoluteFolder::parse(&local_root_folder.to_string_lossy())
            .await
        {
            Ok(folder) => folder,
            Err(error) => {
                println!(
                    "The dev catalog's {name} wasn't added, as its local root folder: {error}. Run `pnpm catalog`, then seed again"
                );
                continue;
            }
        };
        let configuration = ServarrConfiguration {
            url: source
                .url
                .parse()
                .with_context(|| format!("the dev catalog's {name} has an invalid URL"))?,
            quality_profile,
            root_folder_path: source.root_folder_path.to_owned(),
            local_root_folder_path: Some(local_root_folder),
        };
        let created = servarr::create(
            db,
            &config.encryption_key,
            source.app,
            configuration,
            &api_key,
        )
        .await?;
        println!("Added the dev catalog's {name} as a Source");

        match media_imports::start(db, created.id(), FilesToImport::New).await {
            Ok(_) => println!("Queued an import of its files, which the server runs"),
            Err(StartMediaImportError::UnsupportedSourceType) => {}
            Err(error) => return Err(error.into()),
        }
    }
    Ok(())
}

/// Returns the folder of the repository's primary worktree.
fn primary_worktree() -> anyhow::Result<PathBuf> {
    let output = Command::new("git")
        .args(["rev-parse", "--path-format=absolute", "--git-common-dir"])
        .output()
        .context("failed to run git")?;
    anyhow::ensure!(output.status.success(), "git didn't find the repository");
    let git_dir = PathBuf::from(String::from_utf8(output.stdout)?.trim());
    git_dir
        .parent()
        .map(PathBuf::from)
        .context("the repository's .git folder has no parent")
}
