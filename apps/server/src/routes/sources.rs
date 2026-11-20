//! Sources, which the Instance Administrator manages, with how the API sends and takes them. Each
//! handler turns the request into the domain's types, calls `domain::sources`, and turns its
//! answer or error into JSON and a status.

use axum::{
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use secrecy::SecretString;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use utoipa_axum::{router::OpenApiRouter, routes};

use crate::{
    ApiContext,
    api_client::HttpClient,
    auth::InstanceAdministrator,
    db::Pool,
    domain::{
        InternalError,
        contents::MediaType,
        sources::{
            self, CheckExistingSourceError, ConfigurationError, ConfigurationInput,
            ConnectionError, CreateError, DeleteError, FilesystemConfigurationInput,
            QualityProfile, Servarr, ServarrApp, ServarrConfigurationError,
            ServarrConfigurationInput, Source, SourceConfiguration, SourceId, UpdateError,
        },
    },
    error::{self, ApiError, ErrorBody},
    routes::{Json, Path},
    utils::{encryption::EncryptionKey, filesystem::FolderError},
};

/// Returns the endpoints that manage Sources, which only the Instance Administrator calls.
pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new()
        .routes(routes!(list_sources, create_source))
        .routes(routes!(update_source, delete_source))
        .routes(routes!(check_new_source))
        .routes(routes!(check_existing_source))
}

/// Returns every Source, oldest first.
#[utoipa::path(
    get,
    path = "/sources",
    responses((status = OK, body = Vec<SourceResponse>)),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn list_sources(
    State(db): State<Pool>,
    _: InstanceAdministrator,
) -> Result<Json<Vec<SourceResponse>>, ApiError> {
    let sources = sources::list(&db).await?;
    Ok(Json(
        sources.into_iter().map(SourceResponse::from).collect(),
    ))
}

/// Validates the configuration, then creates a Source with it.
#[utoipa::path(
    post,
    path = "/sources",
    request_body = SourceConfigurationBody,
    responses(
        (status = CREATED, body = SourceResponse),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<CreateSourceRequestError>, description = "WatchClub can't read the folders or call the app with this configuration"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn create_source(
    State(db): State<Pool>,
    State(key): State<EncryptionKey>,
    State(http_client): State<HttpClient>,
    _: InstanceAdministrator,
    Json(configuration): Json<SourceConfigurationBody>,
) -> Result<(StatusCode, Json<SourceResponse>), CreateSourceRequestError> {
    let source = sources::create(&db, configuration.into_input(&key), &key, &http_client).await?;
    Ok((StatusCode::CREATED, Json(source.into())))
}

/// Validates the configuration, then gives it to the Source, which keeps its type and Media Type,
/// and its API key unless the configuration has another one.
#[utoipa::path(
    put,
    path = "/sources/{id}",
    params(("id" = SourceId, Path, description = "The Source's ID")),
    request_body = SourceConfigurationBody,
    responses(
        (status = OK, body = SourceResponse),
        (status = NOT_FOUND, body = ErrorBody<UpdateSourceRequestError>, description = "There's no such Source"),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<UpdateSourceRequestError>, description = "WatchClub can't read the folders or call the app with this configuration, or it's for another type or Media Type"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn update_source(
    State(db): State<Pool>,
    State(key): State<EncryptionKey>,
    State(http_client): State<HttpClient>,
    _: InstanceAdministrator,
    Path(id): Path<SourceId>,
    Json(configuration): Json<SourceConfigurationBody>,
) -> Result<Json<SourceResponse>, UpdateSourceRequestError> {
    let source =
        sources::update(&db, id, configuration.into_input(&key), &key, &http_client).await?;
    Ok(Json(source.into()))
}

/// Deletes the Source.
#[utoipa::path(
    delete,
    path = "/sources/{id}",
    params(("id" = SourceId, Path, description = "The Source's ID")),
    responses(
        (status = NO_CONTENT, description = "Deleted"),
        (status = NOT_FOUND, body = ErrorBody<DeleteSourceRequestError>, description = "There's no such Source"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn delete_source(
    State(db): State<Pool>,
    _: InstanceAdministrator,
    Path(id): Path<SourceId>,
) -> Result<StatusCode, DeleteSourceRequestError> {
    sources::delete(&db, id).await?;
    Ok(StatusCode::NO_CONTENT)
}

/// Returns the quality profiles and root folders of a Radarr, Sonarr or Sportarr app, for a new
/// Source, once it checked that the app is at the URL and takes the API key.
#[utoipa::path(
    post,
    path = "/sources/check",
    request_body = CheckNewSourceRequest,
    responses(
        (status = OK, body = CheckSourceResponse),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<ConnectionError>, description = "WatchClub can't call the app with this URL and API key"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn check_new_source(
    State(key): State<EncryptionKey>,
    State(http_client): State<HttpClient>,
    _: InstanceAdministrator,
    Json(request): Json<CheckNewSourceRequest>,
) -> Result<Json<CheckSourceResponse>, ConnectionError> {
    let api_key = key.encrypt(&request.api_key);
    let servarr = Servarr::connect(request.app, &request.url, &api_key, &key, &http_client).await?;
    Ok(Json(CheckSourceResponse::list(&servarr).await?))
}

/// Returns the quality profiles and root folders of a Radarr, Sonarr or Sportarr Source's app, once
/// it checked that the app is at the URL and takes the API key: the one in the request, or else the
/// Source's saved one.
#[utoipa::path(
    post,
    path = "/sources/{id}/check",
    params(("id" = SourceId, Path, description = "The Source's ID")),
    request_body = CheckExistingSourceRequest,
    responses(
        (status = OK, body = CheckSourceResponse),
        (status = NOT_FOUND, body = ErrorBody<CheckExistingSourceRequestError>, description = "There's no such Radarr, Sonarr or Sportarr Source"),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<ConnectionError>, description = "WatchClub can't call the app with this URL and API key"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn check_existing_source(
    State(db): State<Pool>,
    State(key): State<EncryptionKey>,
    State(http_client): State<HttpClient>,
    _: InstanceAdministrator,
    Path(id): Path<SourceId>,
    Json(request): Json<CheckExistingSourceRequest>,
) -> Result<Json<CheckSourceResponse>, CheckExistingSourceRequestError> {
    let api_key = request.api_key.map(|api_key| key.encrypt(&api_key));
    let servarr =
        sources::check_existing_source(&db, id, &request.url, api_key, &key, &http_client).await?;
    Ok(Json(CheckSourceResponse::list(&servarr).await?))
}

/// The quality profiles and root folders of the app that a check called, which the Instance
/// Administrator chooses the Source's from.
#[derive(Serialize, ToSchema)]
#[schema(as = SourceCheck)]
struct CheckSourceResponse {
    quality_profiles: Vec<QualityProfile>,
    /// The paths of its root folders, as it sees them, such as `/movies`
    root_folders: Vec<String>,
}

impl CheckSourceResponse {
    /// Lists the app's quality profiles and root folders, at once.
    async fn list(servarr: &Servarr) -> Result<Self, ConnectionError> {
        let (quality_profiles, root_folders) =
            tokio::try_join!(servarr.list_quality_profiles(), servarr.list_root_folders())?;
        Ok(Self {
            quality_profiles,
            root_folders,
        })
    }
}

/// A Source, with its Source Configuration, which depends on its type.
#[derive(Serialize, ToSchema)]
#[serde(tag = "type", rename_all = "snake_case")]
#[schema(as = Source)]
enum SourceResponse {
    /// A folder on the server, whose files and subfolders' files have the Media Type
    Filesystem {
        id: SourceId,
        media_type: MediaType,
        path: String,
    },
    Radarr(ServarrSourceResponse),
    Sonarr(ServarrSourceResponse),
    Sportarr(ServarrSourceResponse),
}

/// A Radarr, Sonarr or Sportarr Source, with its Source Configuration.
#[derive(Serialize, ToSchema)]
#[schema(as = ServarrSource)]
struct ServarrSourceResponse {
    id: SourceId,
    /// The Media Type of the files the app downloads
    media_type: MediaType,
    /// The address WatchClub calls the app at
    url: String,
    /// The quality the app downloads requested Content in
    quality_profile: QualityProfile,
    /// The folder the app downloads requested Content to, as the app sees it
    root_folder_path: String,
    /// The root folder, as WatchClub sees it when that's another path, such as in Docker
    #[schema(required = true)]
    local_root_folder_path: Option<String>,
}

impl From<Source> for SourceResponse {
    fn from(source: Source) -> Self {
        let media_type = source.configuration.media_type();
        match source.configuration {
            SourceConfiguration::Filesystem(configuration) => Self::Filesystem {
                id: source.id,
                media_type,
                path: configuration.path.as_str().to_owned(),
            },
            SourceConfiguration::Servarr(configuration) => {
                let app = configuration.app;
                let response = ServarrSourceResponse {
                    id: source.id,
                    media_type,
                    url: configuration.url,
                    quality_profile: configuration.quality_profile,
                    root_folder_path: configuration.root_folder_path,
                    local_root_folder_path: configuration
                        .local_root_folder_path
                        .map(|folder| folder.as_str().to_owned()),
                };
                match app {
                    ServarrApp::Radarr => Self::Radarr(response),
                    ServarrApp::Sonarr => Self::Sonarr(response),
                    ServarrApp::Sportarr => Self::Sportarr(response),
                }
            }
        }
    }
}

/// The Source Configuration the Instance Administrator enters, which depends on the Source's type.
#[derive(Deserialize, ToSchema)]
#[serde(tag = "type", rename_all = "snake_case")]
#[schema(as = SourceConfiguration)]
enum SourceConfigurationBody {
    /// A folder on the server, whose files and subfolders' files have the Media Type
    Filesystem {
        media_type: MediaType,
        path: String,
    },
    Radarr(ServarrConfigurationBody),
    Sonarr(ServarrConfigurationBody),
    Sportarr(ServarrConfigurationBody),
}

/// The Source Configuration the Instance Administrator enters for a Radarr, Sonarr or Sportarr
/// Source.
#[derive(Deserialize, ToSchema)]
#[schema(as = ServarrConfiguration)]
struct ServarrConfigurationBody {
    /// The address WatchClub calls the app at
    url: String,
    /// The app's API key. A new Source needs one; leaving it out keeps a Source's saved one
    #[schema(value_type = Option<String>)]
    api_key: Option<SecretString>,
    /// One of the app's quality profiles, which `POST /sources/check` lists
    quality_profile_id: i32,
    /// One of the app's root folders, which `POST /sources/check` lists
    root_folder_path: String,
    /// The root folder, as WatchClub sees it when that's another path, such as in Docker, or null
    // Required even though it can be null, so that leaving it out doesn't clear it
    #[serde(deserialize_with = "Option::deserialize")]
    #[schema(required = true)]
    local_root_folder_path: Option<String>,
}

impl SourceConfigurationBody {
    /// Returns the configuration to validate, with its API key encrypted, which WatchClub decrypts
    /// only to call the app.
    fn into_input(self, encryption_key: &EncryptionKey) -> ConfigurationInput {
        let (app, configuration) = match self {
            Self::Filesystem { media_type, path } => {
                return ConfigurationInput::Filesystem(FilesystemConfigurationInput {
                    media_type,
                    path,
                });
            }
            Self::Radarr(configuration) => (ServarrApp::Radarr, configuration),
            Self::Sonarr(configuration) => (ServarrApp::Sonarr, configuration),
            Self::Sportarr(configuration) => (ServarrApp::Sportarr, configuration),
        };
        ConfigurationInput::Servarr(ServarrConfigurationInput {
            app,
            url: configuration.url,
            api_key: configuration
                .api_key
                .map(|api_key| encryption_key.encrypt(&api_key)),
            quality_profile_id: configuration.quality_profile_id,
            root_folder_path: configuration.root_folder_path,
            local_root_folder_path: configuration.local_root_folder_path,
        })
    }
}

/// A Radarr, Sonarr or Sportarr app to check, for a new Source.
#[derive(Deserialize, ToSchema)]
#[schema(as = ServarrConnection)]
struct CheckNewSourceRequest {
    #[serde(rename = "type")]
    app: ServarrApp,
    /// The address WatchClub calls the app at
    url: String,
    #[schema(value_type = String)]
    api_key: SecretString,
}

/// The address of a Source's app to check, and the API key, unless it's the Source's saved one.
#[derive(Deserialize, ToSchema)]
#[schema(as = SourceConnection)]
struct CheckExistingSourceRequest {
    /// The address WatchClub calls the app at
    url: String,
    /// Another API key, or none to use the Source's saved one
    #[schema(value_type = Option<String>)]
    api_key: Option<SecretString>,
}

/// Answers with a 422 when WatchClub can't call an app with a URL and an API key.
impl IntoResponse for ConnectionError {
    fn into_response(self) -> Response {
        error::response(StatusCode::UNPROCESSABLE_ENTITY, &self)
    }
}

/// The failures of a request to check a Source's app.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum CheckExistingSourceRequestError {
    #[error("no such Radarr, Sonarr or Sportarr Source")]
    NotFound,
    /// Answers as its `ConnectionError`
    #[error(transparent)]
    #[serde(skip)]
    Connection(#[from] ConnectionError),
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl From<CheckExistingSourceError> for CheckExistingSourceRequestError {
    fn from(error: CheckExistingSourceError) -> Self {
        match error {
            CheckExistingSourceError::SourceNotFound => Self::NotFound,
            CheckExistingSourceError::Connection(error) => Self::Connection(error),
            CheckExistingSourceError::Internal(error) => Self::Internal(error.into()),
        }
    }
}

impl IntoResponse for CheckExistingSourceRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::NotFound => error::response(StatusCode::NOT_FOUND, &self),
            Self::Connection(error) => error.into_response(),
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}

/// The failures of a request to create a Source.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum CreateSourceRequestError {
    #[error("WatchClub can't read the folder")]
    InvalidFilesystemConfiguration { error: FolderError },
    #[error("WatchClub can't use the app with this configuration")]
    InvalidServarrConfiguration { error: ServarrConfigurationError },
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl From<CreateError> for CreateSourceRequestError {
    fn from(error: CreateError) -> Self {
        match error {
            CreateError::InvalidConfiguration(ConfigurationError::Filesystem(error)) => {
                Self::InvalidFilesystemConfiguration { error }
            }
            CreateError::InvalidConfiguration(ConfigurationError::Servarr(error)) => {
                Self::InvalidServarrConfiguration { error }
            }
            CreateError::Internal(error) => Self::Internal(error.into()),
        }
    }
}

impl IntoResponse for CreateSourceRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::InvalidFilesystemConfiguration { .. }
            | Self::InvalidServarrConfiguration { .. } => {
                error::response(StatusCode::UNPROCESSABLE_ENTITY, &self)
            }
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}

/// The failures of a request to update a Source.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum UpdateSourceRequestError {
    #[error("WatchClub can't read the folder")]
    InvalidFilesystemConfiguration { error: FolderError },
    #[error("WatchClub can't use the app with this configuration")]
    InvalidServarrConfiguration { error: ServarrConfigurationError },
    #[error("a Source keeps its type and Media Type")]
    TypeChanged,
    #[error("no such Source")]
    NotFound,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl From<UpdateError> for UpdateSourceRequestError {
    fn from(error: UpdateError) -> Self {
        match error {
            UpdateError::SourceNotFound => Self::NotFound,
            UpdateError::TypeChanged => Self::TypeChanged,
            UpdateError::InvalidConfiguration(ConfigurationError::Filesystem(error)) => {
                Self::InvalidFilesystemConfiguration { error }
            }
            UpdateError::InvalidConfiguration(ConfigurationError::Servarr(error)) => {
                Self::InvalidServarrConfiguration { error }
            }
            UpdateError::Internal(error) => Self::Internal(error.into()),
        }
    }
}

impl IntoResponse for UpdateSourceRequestError {
    fn into_response(self) -> Response {
        let status = match self {
            Self::InvalidFilesystemConfiguration { .. }
            | Self::InvalidServarrConfiguration { .. }
            | Self::TypeChanged => StatusCode::UNPROCESSABLE_ENTITY,
            Self::NotFound => StatusCode::NOT_FOUND,
            Self::Internal(error) => return ApiError::from(error).into_response(),
        };
        error::response(status, &self)
    }
}

/// The failures of a request to delete a Source.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum DeleteSourceRequestError {
    #[error("no such Source")]
    NotFound,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] InternalError),
}

impl From<DeleteError> for DeleteSourceRequestError {
    fn from(error: DeleteError) -> Self {
        match error {
            DeleteError::SourceNotFound => Self::NotFound,
            DeleteError::Internal(error) => Self::Internal(error.into()),
        }
    }
}

impl IntoResponse for DeleteSourceRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::NotFound => error::response(StatusCode::NOT_FOUND, &self),
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}
