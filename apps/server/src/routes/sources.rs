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
        contents::MediaType,
        sources::{
            self, ConnectionError, DeleteError, QualityProfile, ServarrApp, ServarrChoices,
            ServarrConfiguration, ServarrConfigurationUpdate, Source, SourceConfiguration,
            SourceId, UpdateError,
        },
    },
    error::{self, ApiError, ErrorBody},
    routes::{Json, Path},
    utils::{
        encryption::EncryptionKey,
        filesystem::{AbsoluteFolder, FolderError},
    },
};

/// Returns the endpoints that manage Sources, which only the Instance Administrator calls.
pub(super) fn routes() -> OpenApiRouter<ApiContext> {
    OpenApiRouter::new()
        .routes(routes!(list_sources, create_source))
        .routes(routes!(update_source, delete_source))
        .routes(routes!(test_new_source_servarr_connection))
        .routes(routes!(test_saved_source_servarr_connection))
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
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<CreateSourceRequestError>, description = "The configuration is invalid, such as a folder WatchClub can't read"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn create_source(
    State(db): State<Pool>,
    State(key): State<EncryptionKey>,
    _: InstanceAdministrator,
    Json(body): Json<SourceConfigurationBody>,
) -> Result<(StatusCode, Json<SourceResponse>), CreateSourceRequestError> {
    let source = match body {
        SourceConfigurationBody::Filesystem { media_type, path } => {
            let path = AbsoluteFolder::parse(&path)
                .await
                .map_err(ApiFolderError::from)?;
            sources::create_filesystem_source(&db, media_type, path).await?
        }
        SourceConfigurationBody::Radarr(body) => {
            let configuration = body.parse_for_new_source(ServarrApp::Radarr, &key).await?;
            sources::create_servarr_source(&db, configuration).await?
        }
        SourceConfigurationBody::Sonarr(body) => {
            let configuration = body.parse_for_new_source(ServarrApp::Sonarr, &key).await?;
            sources::create_servarr_source(&db, configuration).await?
        }
        SourceConfigurationBody::Sportarr(body) => {
            let configuration = body
                .parse_for_new_source(ServarrApp::Sportarr, &key)
                .await?;
            sources::create_servarr_source(&db, configuration).await?
        }
    };

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
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<UpdateSourceRequestError>, description = "The configuration is invalid, such as a folder WatchClub can't read, or it's for another type or Media Type"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn update_source(
    State(db): State<Pool>,
    State(key): State<EncryptionKey>,
    _: InstanceAdministrator,
    Path(id): Path<SourceId>,
    Json(body): Json<SourceConfigurationBody>,
) -> Result<Json<SourceResponse>, UpdateSourceRequestError> {
    let source = sources::get(&db, id)
        .await?
        .ok_or(UpdateSourceRequestError::NotFound)?;

    let updated = match source.configuration {
        SourceConfiguration::Filesystem(saved) => {
            let path = body
                .into_filesystem(saved.media_type)
                .ok_or(UpdateSourceRequestError::TypeChanged)?;

            let path = AbsoluteFolder::parse(&path)
                .await
                .map_err(ApiFolderError::from)?;
            sources::update_filesystem_source(&db, id, path).await?
        }
        SourceConfiguration::Servarr(saved) => {
            let body = body
                .into_servarr(saved.app)
                .ok_or(UpdateSourceRequestError::TypeChanged)?;

            let configuration = body.parse_for_update(&key).await?;
            sources::update_servarr_source(&db, id, configuration).await?
        }
    };

    Ok(Json(updated.into()))
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

/// Tests the connection to a Radarr, Sonarr or Sportarr app, for a new Source: checks that the app
/// answers at the URL and takes the API key, then returns its quality profiles and root folders.
#[utoipa::path(
    post,
    path = "/sources/test-servarr-connection",
    request_body = TestNewSourceServarrConnectionRequest,
    responses(
        (status = OK, body = ServarrChoices),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<ApiConnectionError>, description = "WatchClub can't call the app with this URL and API key"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn test_new_source_servarr_connection(
    State(http_client): State<HttpClient>,
    _: InstanceAdministrator,
    Json(request): Json<TestNewSourceServarrConnectionRequest>,
) -> Result<Json<ServarrChoices>, ApiConnectionError> {
    let choices =
        sources::test_servarr_connection(request.app, &request.url, &request.api_key, &http_client)
            .await?;
    Ok(Json(choices))
}

/// Tests the connection to the app of a Radarr, Sonarr or Sportarr Source, at the URL and with the
/// API key in the request, or else the Source's saved one, then returns the app's quality profiles
/// and root folders.
#[utoipa::path(
    post,
    path = "/sources/{id}/test-servarr-connection",
    params(("id" = SourceId, Path, description = "The Source's ID")),
    request_body = TestSavedSourceServarrConnectionRequest,
    responses(
        (status = OK, body = ServarrChoices),
        (status = NOT_FOUND, body = ErrorBody<TestSavedSourceServarrConnectionRequestError>, description = "There's no such Radarr, Sonarr or Sportarr Source"),
        (status = UNPROCESSABLE_ENTITY, body = ErrorBody<ApiConnectionError>, description = "WatchClub can't call the app with this URL and API key"),
    ),
    security(("session_cookie" = ["instance_administrator"]), ("session_token" = ["instance_administrator"])),
)]
async fn test_saved_source_servarr_connection(
    State(db): State<Pool>,
    State(key): State<EncryptionKey>,
    State(http_client): State<HttpClient>,
    _: InstanceAdministrator,
    Path(id): Path<SourceId>,
    Json(request): Json<TestSavedSourceServarrConnectionRequest>,
) -> Result<Json<ServarrChoices>, TestSavedSourceServarrConnectionRequestError> {
    let source = sources::get(&db, id)
        .await?
        .ok_or(TestSavedSourceServarrConnectionRequestError::NotFound)?;
    let SourceConfiguration::Servarr(configuration) = source.configuration else {
        return Err(TestSavedSourceServarrConnectionRequestError::NotFound);
    };

    // No API key keeps the Source's saved one
    let api_key = match request.api_key {
        Some(api_key) => api_key,
        None => configuration
            .decrypt_api_key(&key)
            .map_err(ApiConnectionError::from)?,
    };
    let choices =
        sources::test_servarr_connection(configuration.app, &request.url, &api_key, &http_client)
            .await
            .map_err(ApiConnectionError::from)?;
    Ok(Json(choices))
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
                    url: configuration.url.to_string(),
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
    /// One of the app's quality profiles, which `POST /sources/test-servarr-connection` lists
    quality_profile: QualityProfile,
    /// One of the app's root folders, which `POST /sources/test-servarr-connection` lists
    root_folder_path: String,
    /// The root folder, as WatchClub sees it when that's another path, such as in Docker, or null
    // Required even though it can be null, so that leaving it out doesn't clear it
    #[serde(deserialize_with = "Option::deserialize")]
    #[schema(required = true)]
    local_root_folder_path: Option<String>,
}

impl ServarrConfigurationBody {
    /// Returns the configuration of a new Source of `app`, which needs an API key, as
    /// `parse_for_update` checks it.
    async fn parse_for_new_source(
        self,
        app: ServarrApp,
        encryption_key: &EncryptionKey,
    ) -> Result<ServarrConfiguration, ServarrConfigurationError> {
        let ServarrConfigurationUpdate {
            url,
            api_key,
            quality_profile,
            root_folder_path,
            local_root_folder_path,
        } = self.parse_for_update(encryption_key).await?;
        let api_key = api_key.ok_or(ApiConnectionError::InvalidApiKey)?;

        Ok(ServarrConfiguration {
            app,
            url,
            api_key,
            quality_profile,
            root_folder_path,
            local_root_folder_path,
        })
    }

    /// Returns the new configuration of a Source, with its API key encrypted, once WatchClub found
    /// the local root folder and parsed the URL. Doesn't call the app: the Instance Administrator
    /// chose the quality profile and root folder among those `test_servarr_connection` listed.
    async fn parse_for_update(
        self,
        encryption_key: &EncryptionKey,
    ) -> Result<ServarrConfigurationUpdate, ServarrConfigurationError> {
        // None or blank when WatchClub sees the root folder at the app's path
        let local_root_folder_path = match self.local_root_folder_path.as_deref().map(str::trim) {
            Some(path) if !path.is_empty() => Some(
                AbsoluteFolder::parse(path)
                    .await
                    .map_err(|error| ServarrConfigurationError::LocalRootFolder(error.into()))?,
            ),
            _ => None,
        };
        let url = self
            .url
            .parse()
            .map_err(|_| ApiConnectionError::InvalidServarrUrl)?;

        Ok(ServarrConfigurationUpdate {
            url,
            api_key: self.api_key.map(|api_key| encryption_key.encrypt(&api_key)),
            quality_profile: self.quality_profile,
            root_folder_path: self.root_folder_path,
            local_root_folder_path,
        })
    }
}

impl SourceConfigurationBody {
    /// Returns the folder of a Filesystem Source of `media_type`, or None when the body is for
    /// another type or Media Type.
    fn into_filesystem(self, media_type: MediaType) -> Option<String> {
        match self {
            Self::Filesystem {
                media_type: body_media_type,
                path,
            } if body_media_type == media_type => Some(path),
            _ => None,
        }
    }

    /// Returns the configuration of a Source of `app`, or None when the body is for another type.
    fn into_servarr(self, app: ServarrApp) -> Option<ServarrConfigurationBody> {
        match (app, self) {
            (ServarrApp::Radarr, Self::Radarr(configuration))
            | (ServarrApp::Sonarr, Self::Sonarr(configuration))
            | (ServarrApp::Sportarr, Self::Sportarr(configuration)) => Some(configuration),
            _ => None,
        }
    }
}

/// A Radarr, Sonarr or Sportarr app to test the connection to, for a new Source.
#[derive(Deserialize, ToSchema)]
#[schema(as = ServarrConnection)]
struct TestNewSourceServarrConnectionRequest {
    #[serde(rename = "type")]
    app: ServarrApp,
    /// The address WatchClub calls the app at
    url: String,
    #[schema(value_type = String)]
    api_key: SecretString,
}

/// The address of a Source's app to test the connection to, and the API key, unless it's the
/// Source's saved one.
#[derive(Deserialize, ToSchema)]
#[schema(as = ServarrSourceConnection)]
struct TestSavedSourceServarrConnectionRequest {
    /// The address WatchClub calls the app at
    url: String,
    /// Another API key, or none to use the Source's saved one
    #[schema(value_type = Option<String>)]
    api_key: Option<SecretString>,
}

/// The reason WatchClub can't use a Source's app: which of its URL and API key the Instance
/// Administrator has to change. The logs say why.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
#[schema(as = ConnectionError)]
enum ApiConnectionError {
    /// It isn't an http or https URL, nothing answers there, or what answers isn't the app the
    /// Source expects, or answers with an error
    #[error("the URL doesn't lead to the app's API")]
    InvalidServarrUrl,
    /// There's none, WatchClub can't decrypt the saved one, or the app rejects it
    #[error("there's no API key the app takes")]
    InvalidApiKey,
}

impl From<ConnectionError> for ApiConnectionError {
    fn from(error: ConnectionError) -> Self {
        match error {
            ConnectionError::InvalidServarrUrl => Self::InvalidServarrUrl,
            ConnectionError::InvalidApiKey => Self::InvalidApiKey,
        }
    }
}

/// Answers with a 422 when WatchClub can't call an app with a URL and an API key.
impl IntoResponse for ApiConnectionError {
    fn into_response(self) -> Response {
        error::response(StatusCode::UNPROCESSABLE_ENTITY, &self)
    }
}

/// The reasons WatchClub can't read a folder.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
#[schema(as = FolderError)]
enum ApiFolderError {
    /// Such as `movies` rather than `/media/movies`, or the root, which is the whole server rather
    /// than one of its folders
    #[error("the path doesn't start from the root")]
    NotAbsolute,
    /// Nothing is there, or a file is
    #[error("no folder is at the path on the server")]
    NotFound,
}

impl From<FolderError> for ApiFolderError {
    fn from(error: FolderError) -> Self {
        match error {
            FolderError::NotAbsolute => Self::NotAbsolute,
            FolderError::NotFound => Self::NotFound,
        }
    }
}

/// The failures of a request to test the connection to a Radarr, Sonarr or Sportarr Source's app.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum TestSavedSourceServarrConnectionRequestError {
    #[error("no such Radarr, Sonarr or Sportarr Source")]
    NotFound,
    /// Answers as its `ApiConnectionError`
    #[error(transparent)]
    #[serde(skip)]
    Connection(#[from] ApiConnectionError),
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
}

impl IntoResponse for TestSavedSourceServarrConnectionRequestError {
    fn into_response(self) -> Response {
        match self {
            Self::NotFound => error::response(StatusCode::NOT_FOUND, &self),
            Self::Connection(error) => error.into_response(),
            Self::Internal(error) => ApiError::from(error).into_response(),
        }
    }
}

/// The first error WatchClub found in the Source Configuration the Instance Administrator entered
/// for a Radarr, Sonarr or Sportarr Source: the part to change, and why.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "part", rename_all = "snake_case")]
enum ServarrConfigurationError {
    /// The app's URL or API key
    #[error(transparent)]
    Connection(#[from] ApiConnectionError),
    #[error("the local root folder: {0}")]
    LocalRootFolder(ApiFolderError),
}

/// The failures of a request to create a Source.
#[derive(Debug, Serialize, ToSchema, thiserror::Error)]
#[serde(tag = "code", rename_all = "snake_case")]
enum CreateSourceRequestError {
    #[error("WatchClub can't read the folder")]
    InvalidFilesystemConfiguration {
        #[from]
        error: ApiFolderError,
    },
    #[error("the app's configuration is invalid")]
    InvalidServarrConfiguration {
        #[from]
        error: ServarrConfigurationError,
    },
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
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
    InvalidFilesystemConfiguration {
        #[from]
        error: ApiFolderError,
    },
    #[error("the app's configuration is invalid")]
    InvalidServarrConfiguration {
        #[from]
        error: ServarrConfigurationError,
    },
    #[error("a Source keeps its type and Media Type")]
    TypeChanged,
    #[error("no such Source")]
    NotFound,
    #[error(transparent)]
    #[serde(skip)]
    Internal(#[from] anyhow::Error),
}

impl From<UpdateError> for UpdateSourceRequestError {
    fn from(error: UpdateError) -> Self {
        match error {
            UpdateError::SourceNotFound => Self::NotFound,
            UpdateError::Internal(error) => Self::Internal(error),
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
    Internal(#[from] anyhow::Error),
}

impl From<DeleteError> for DeleteSourceRequestError {
    fn from(error: DeleteError) -> Self {
        match error {
            DeleteError::SourceNotFound => Self::NotFound,
            DeleteError::Internal(error) => Self::Internal(error),
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
