//! Radarr, Sonarr and Sportarr Sources: their app, their Source Configuration, creating and updating
//! them, the connection test that checks the app at a URL takes an API key and lists the quality
//! profiles and root folders the Instance Administrator chooses from, and the files a Source has.
//! `client` calls the app.

mod client;

use anyhow::Context;
use reqwest::StatusCode;
use secrecy::SecretString;
use serde::{Deserialize, Serialize};
use sqlx_otel::QueryAnnotateExt;
use tracing::Level;
use utoipa::ToSchema;

use self::client::{RadarrMovie, ServarrClient};
use super::{Source, SourceId, SourceType, UpdateSourceError};
use crate::{
    api_client::{ApiCredentialsError, ApiUrl, ApiUrlError, HttpClient},
    db::Pool,
    domain::contents::{MediaType, metadata::TmdbId},
    utils::{
        encryption::{EncryptedSecret, EncryptionKey},
        filesystem::AbsoluteFolder,
    },
};

/// One of the apps that a Source can be.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum ServarrApp {
    Radarr,
    Sonarr,
    Sportarr,
}

impl ServarrApp {
    /// Returns its name, as it calls itself.
    pub const fn name(self) -> &'static str {
        match self {
            Self::Radarr => "Radarr",
            Self::Sonarr => "Sonarr",
            Self::Sportarr => "Sportarr",
        }
    }

    /// Returns the Media Type of the files it downloads.
    pub const fn media_type(self) -> MediaType {
        match self {
            Self::Radarr => MediaType::Movie,
            Self::Sonarr => MediaType::TvShowEpisode,
            Self::Sportarr => MediaType::SportsEvent,
        }
    }

    /// Returns the segments of its API's path under its URL, such as `api/v3`. Sportarr's own API,
    /// rather than the copy of Sonarr's it also has, which says it's Sonarr.
    const fn api_path(self) -> &'static [&'static str] {
        match self {
            Self::Radarr | Self::Sonarr => &["api", "v3"],
            Self::Sportarr => &["api"],
        }
    }
}

/// A quality profile of an app: the quality it downloads requested Content in.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct QualityProfile {
    /// The app's ID of the profile
    pub id: i32,
    pub name: String,
}

/// The Source Configuration of a Radarr, Sonarr or Sportarr Source, without its API key: WatchClub
/// keeps it encrypted, and only decrypts it to call the app.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ServarrConfiguration {
    /// The address WatchClub calls the app at, with its API under it
    pub url: ApiUrl,
    /// The quality the app downloads requested Content in
    pub quality_profile: QualityProfile,
    /// The folder the app downloads requested Content to, as the app sees it
    pub root_folder_path: String,
    /// The root folder, as WatchClub sees it when that's another path, such as in Docker
    pub local_root_folder_path: Option<AbsoluteFolder>,
}

impl ServarrConfiguration {
    /// Returns where WatchClub sees the file at `path`, as the app sees it, or None when the file
    /// isn't in the Source's root folder. Doesn't support an app on Windows, whose paths, such as
    /// `D:\Movies\…`, are never in the root folder.
    pub fn local_path(&self, path: &str) -> Option<String> {
        let root_folder = self.root_folder_path.trim_end_matches('/');
        // Also checks that the root folder is a whole folder of the path: `/movies` isn't one of
        // `/movies-4k/…`
        let relative_path = path.strip_prefix(root_folder)?.strip_prefix('/')?;
        let local_root_folder = self
            .local_root_folder_path
            .as_ref()
            .map_or(root_folder, AbsoluteFolder::as_str);
        Some(format!("{local_root_folder}/{relative_path}"))
    }
}

/// The file of a Movie that a Radarr Source has, with the Movie's IDs.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MovieFile {
    /// Where WatchClub sees it on the server
    pub path: String,
    pub tmdb_id: TmdbId,
    /// The Movie's IMDb ID, such as `tt0133093`, when Radarr knows it
    pub imdb_id: Option<String>,
}

/// The quality profiles and root folders of a Radarr, Sonarr or Sportarr app, which the Instance
/// Administrator chooses a Source's from.
#[derive(Debug, PartialEq, Eq, Serialize, ToSchema)]
pub struct ServarrChoices {
    pub quality_profiles: Vec<QualityProfile>,
    /// The paths of its root folders, as it sees them, such as `/movies`
    pub root_folders: Vec<String>,
}

/// The reason WatchClub can't use a Source's app: which of its URL and API key the Instance
/// Administrator has to change. The logs say why.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum TestConnectionError {
    /// It isn't an http or https URL, nothing answers there, or what answers isn't the app the
    /// Source expects, or answers with an error
    #[error("the URL doesn't lead to the app's API")]
    InvalidUrl,
    /// It can't go in a request, WatchClub can't decrypt the saved one, or the app rejects it
    #[error("there's no API key the app takes")]
    InvalidApiKey,
}

/// The reason the connection to a Radarr, Sonarr or Sportarr Source's app wasn't tested.
#[derive(Debug, thiserror::Error)]
pub enum TestSavedConnectionError {
    /// There's no Radarr, Sonarr or Sportarr Source with the ID
    #[error("no such Radarr, Sonarr or Sportarr Source")]
    NotFound,
    #[error(transparent)]
    Connection(#[from] TestConnectionError),
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// The reason a Source's files weren't listed.
#[derive(Debug, thiserror::Error)]
pub enum ListFilesError {
    /// There's no Radarr Source with the ID, such as one deleted meanwhile
    #[error("no such Radarr Source")]
    NotFound,
    #[error(transparent)]
    Connection(#[from] TestConnectionError),
    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

/// Creates a Source of the app with the configuration, which keeps the API key encrypted with
/// `encryption_key`, and returns it.
#[tracing::instrument(skip_all, fields(servarr.app = app.name()))]
pub async fn create(
    db: &Pool,
    encryption_key: &EncryptionKey,
    app: ServarrApp,
    configuration: ServarrConfiguration,
    api_key: &SecretString,
) -> anyhow::Result<Source> {
    let api_key = encryption_key.encrypt(api_key);
    let id = sqlx::query_scalar!(
        r#"
        INSERT INTO sources (
            source_type, media_type, url, api_key_encrypted, quality_profile_id,
            quality_profile_name, root_folder_path, local_root_folder_path
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING id
        "#,
        SourceType::from(app),
        app.media_type(),
        configuration.url.as_str(),
        &api_key as &EncryptedSecret,
        configuration.quality_profile.id,
        configuration.quality_profile.name,
        configuration.root_folder_path,
        configuration.local_root_folder_path.as_ref() as Option<&AbsoluteFolder>,
    )
    .with_operation("INSERT", "sources")
    .fetch_one(db)
    .await
    .context("failed to create the app's Source")?;

    Ok(Source::Servarr {
        id,
        app,
        configuration,
    })
}

/// Gives the Radarr, Sonarr or Sportarr Source with this ID the configuration, and the API key
/// encrypted with `encryption_key`, or keeps its saved one without, and returns it. The Source keeps
/// its app.
#[tracing::instrument(skip_all, fields(source.id = %id))]
pub async fn update(
    db: &Pool,
    encryption_key: &EncryptionKey,
    id: SourceId,
    configuration: ServarrConfiguration,
    api_key: Option<&SecretString>,
) -> Result<Source, UpdateSourceError> {
    let api_key = api_key.map(|api_key| encryption_key.encrypt(api_key));
    // Without a new API key, `COALESCE` keeps the one in the row as it is when Postgres writes it,
    // rather than the one the caller read before: a key that another request saved meanwhile stays
    let source_type = sqlx::query_scalar!(
        r#"
        UPDATE sources
        SET url = $2,
            api_key_encrypted = COALESCE($3, api_key_encrypted),
            quality_profile_id = $4,
            quality_profile_name = $5,
            root_folder_path = $6,
            local_root_folder_path = $7
        WHERE id = $1 AND source_type IN ('radarr', 'sonarr', 'sportarr')
        RETURNING source_type
        "#,
        id as SourceId,
        configuration.url.as_str(),
        api_key.as_ref() as Option<&EncryptedSecret>,
        configuration.quality_profile.id,
        configuration.quality_profile.name,
        configuration.root_folder_path,
        configuration.local_root_folder_path.as_ref() as Option<&AbsoluteFolder>,
    )
    .with_operation("UPDATE", "sources")
    .fetch_optional(db)
    .await
    .context("failed to update the app's Source")?
    .ok_or(UpdateSourceError::NotFound)?;

    Ok(Source::Servarr {
        id,
        app: source_type
            .app()
            .expect("the update only finds apps' Sources"),
        configuration,
    })
}

/// Checks that `app` answers at `url` and takes the API key, then returns the app's quality
/// profiles and root folders. Refuses another app, such as Sonarr at a Radarr Source's URL.
#[tracing::instrument(skip_all, fields(servarr.app = app.name()))]
pub async fn test_connection(
    http_client: &HttpClient,
    app: ServarrApp,
    url: &str,
    api_key: &SecretString,
) -> Result<ServarrChoices, TestConnectionError> {
    let url: ApiUrl = url.parse()?;
    let client = ServarrClient::new(http_client, app, &url, api_key)?;

    let app_name = client.fetch_app_name().await.map_err(report_failed_call)?;
    if app_name != app.name() {
        tracing::event!(
            name: "servarr.app.unexpected",
            Level::WARN,
            servarr.app = app.name(),
            exception.message = %format_args!("{app_name} answered, rather than {}", app.name()),
            "another app answered at a Source's URL",
        );
        return Err(TestConnectionError::InvalidUrl);
    }

    let (quality_profiles, root_folders) =
        tokio::try_join!(client.list_quality_profiles(), client.list_root_folders())
            .map_err(report_failed_call)?;
    Ok(ServarrChoices {
        quality_profiles,
        root_folders,
    })
}

/// Tests the connection to the app of the Radarr, Sonarr or Sportarr Source with this ID, at `url`
/// and with `api_key`, or else with the Source's saved API key, as `test_connection` does.
#[tracing::instrument(skip_all, fields(source.id = %id))]
pub async fn test_saved_connection(
    db: &Pool,
    encryption_key: &EncryptionKey,
    http_client: &HttpClient,
    id: SourceId,
    url: &str,
    api_key: Option<SecretString>,
) -> Result<ServarrChoices, TestSavedConnectionError> {
    let saved = sqlx::query!(
        r#"
        SELECT source_type, api_key_encrypted AS "api_key_encrypted!: EncryptedSecret"
        FROM sources
        WHERE id = $1 AND source_type IN ('radarr', 'sonarr', 'sportarr')
        "#,
        id as SourceId,
    )
    .with_operation("SELECT", "sources")
    .fetch_optional(db)
    .await
    .context("failed to find the app's Source")?
    .ok_or(TestSavedConnectionError::NotFound)?;
    let app = saved
        .source_type
        .app()
        .expect("the query only finds apps' Sources");

    let api_key = match api_key {
        Some(api_key) => api_key,
        None => decrypt_api_key(encryption_key, &saved.api_key_encrypted)?,
    };
    Ok(test_connection(http_client, app, url, &api_key).await?)
}

/// Returns the files of the Movies that the Radarr Source with this ID has: those in its root
/// folder and on its quality profile, at the paths WatchClub sees them at.
#[tracing::instrument(skip_all, fields(source.id = %id))]
pub async fn list_movie_files(
    db: &Pool,
    encryption_key: &EncryptionKey,
    http_client: &HttpClient,
    id: SourceId,
) -> Result<Vec<MovieFile>, ListFilesError> {
    let source = super::get(db, id).await?;
    let Some(Source::Servarr {
        app: app @ ServarrApp::Radarr,
        configuration,
        ..
    }) = source
    else {
        return Err(ListFilesError::NotFound);
    };
    let api_key = sqlx::query_scalar!(
        r#"SELECT api_key_encrypted AS "api_key_encrypted!: EncryptedSecret" FROM sources WHERE id = $1"#,
        id as SourceId,
    )
    .with_operation("SELECT", "sources")
    .fetch_optional(db)
    .await
    .context("failed to find the API key of a Source")?
    .ok_or(ListFilesError::NotFound)?;
    let api_key = decrypt_api_key(encryption_key, &api_key)?;

    let client = ServarrClient::new(http_client, app, &configuration.url, &api_key)
        .map_err(TestConnectionError::from)?;
    let movies = client.list_movies().await.map_err(report_failed_call)?;

    Ok(movies
        .into_iter()
        .filter(|movie| movie.quality_profile_id == configuration.quality_profile.id)
        .filter_map(|movie| movie_file(&configuration, movie))
        .collect())
}

/// Returns the Movie's file, where WatchClub sees it, or None when it has none in the Source's root
/// folder.
fn movie_file(configuration: &ServarrConfiguration, movie: RadarrMovie) -> Option<MovieFile> {
    let path = configuration.local_path(&movie.movie_file?.path)?;
    Some(MovieFile {
        path,
        tmdb_id: TmdbId::new(movie.tmdb_id),
        imdb_id: movie.imdb_id.filter(|imdb_id| !imdb_id.is_empty()),
    })
}

/// Returns the saved API key, decrypted to call the app. Refuses it when another key encrypted it,
/// such as before the host changed `ENCRYPTION_KEY`: the Instance Administrator enters it again.
fn decrypt_api_key(
    encryption_key: &EncryptionKey,
    api_key: &EncryptedSecret,
) -> Result<SecretString, TestConnectionError> {
    encryption_key.decrypt(api_key).map_err(|error| {
        tracing::event!(
            name: "sources.api_key.unreadable",
            Level::WARN,
            exception.message = %format_args!("{error:#}"),
            "failed to decrypt a Source's API key",
        );
        TestConnectionError::InvalidApiKey
    })
}

/// Logs why a call to a Source's app failed, which the Instance Administrator doesn't see, and
/// returns the setting the failure shows is wrong: the API key when the app rejects it with a 401,
/// or else the URL.
fn report_failed_call(error: reqwest::Error) -> TestConnectionError {
    let api_key_rejected = error.status() == Some(StatusCode::UNAUTHORIZED);
    // With the causes, such as `connection refused`, which only `anyhow` prints
    let error = anyhow::Error::from(error);
    tracing::event!(
        name: "servarr.call.failed",
        Level::WARN,
        exception.message = %format_args!("{error:#}"),
        "failed to call a Source's app",
    );

    if api_key_rejected {
        TestConnectionError::InvalidApiKey
    } else {
        // Nothing answered, or not as the app's API does, such as a web page, an error or a 404 at
        // the app's API path
        TestConnectionError::InvalidUrl
    }
}

/// Blames the URL when it isn't one WatchClub can call the app's API under, such as `radarr:7878`
/// without `http://`.
impl From<ApiUrlError> for TestConnectionError {
    fn from(_: ApiUrlError) -> Self {
        Self::InvalidUrl
    }
}

/// Blames the API key when it has a character that can't go in a request, such as a line break.
impl From<ApiCredentialsError> for TestConnectionError {
    fn from(_: ApiCredentialsError) -> Self {
        Self::InvalidApiKey
    }
}
