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
            self, DeleteSourceError, Source, SourceId, SourceType, UpdateSourceError, filesystem,
            servarr::{
                self, QualityProfile, ServarrApp, ServarrChoices, ServarrConfiguration,
                TestConnectionError, TestSavedConnectionError,
            },
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
            filesystem::create(&db, media_type, path).await?
        }
        SourceConfigurationBody::Radarr(body) => {
            create_servarr_source(&db, &key, ServarrApp::Radarr, body).await?
        }
        SourceConfigurationBody::Sonarr(body) => {
            create_servarr_source(&db, &key, ServarrApp::Sonarr, body).await?
        }
        SourceConfigurationBody::Sportarr(body) => {
            create_servarr_source(&db, &key, ServarrApp::Sportarr, body).await?
        }
    };

    Ok((StatusCode::CREATED, Json(source.into())))
}

/// Creates a Source of `app` with the configuration the Instance Administrator entered, which needs
/// an API key.
async fn create_servarr_source(
    db: &Pool,
    key: &EncryptionKey,
    app: ServarrApp,
    body: ServarrConfigurationBody,
) -> Result<Source, CreateSourceRequestError> {
    let (configuration, api_key) = body.parse().await?;
    let api_key = api_key.ok_or(ServarrConfigurationError::Connection(
        ApiConnectionError::InvalidApiKey,
    ))?;

    Ok(servarr::create(db, key, app, configuration, &api_key).await?)
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
    // The body describes the whole Source, whose type and Media Type never change
    if body.source_type() != source.source_type() || body.media_type() != source.media_type() {
        return Err(UpdateSourceRequestError::TypeChanged);
    }

    let updated = match body {
        SourceConfigurationBody::Filesystem { path, .. } => {
            let path = AbsoluteFolder::parse(&path)
                .await
                .map_err(ApiFolderError::from)?;
            filesystem::update(&db, id, path).await?
        }
        SourceConfigurationBody::Radarr(body)
        | SourceConfigurationBody::Sonarr(body)
        | SourceConfigurationBody::Sportarr(body) => {
            let (configuration, api_key) = body.parse().await?;
            servarr::update(&db, &key, id, configuration, api_key.as_ref()).await?
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
        servarr::test_connection(&http_client, request.app, &request.url, &request.api_key).await?;
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
    let choices =
        servarr::test_saved_connection(&db, &key, &http_client, id, &request.url, request.api_key)
            .await?;
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
        match source {
            Source::Filesystem {
                id,
                media_type,
                path,
            } => Self::Filesystem {
                id,
                media_type,
                path: path.as_str().to_owned(),
            },
            Source::Servarr {
                id,
                app,
                configuration,
            } => {
                let response = ServarrSourceResponse {
                    id,
                    media_type: app.media_type(),
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

impl SourceConfigurationBody {
    /// Returns the Source Type the body is for.
    const fn source_type(&self) -> SourceType {
        match self {
            Self::Filesystem { .. } => SourceType::Filesystem,
            Self::Radarr(_) => SourceType::Radarr,
            Self::Sonarr(_) => SourceType::Sonarr,
            Self::Sportarr(_) => SourceType::Sportarr,
        }
    }

    /// Returns the Media Type of the Source the body is for: the one it chose for a folder, or its
    /// app's.
    const fn media_type(&self) -> MediaType {
        match self {
            Self::Filesystem { media_type, .. } => *media_type,
            Self::Radarr(_) => ServarrApp::Radarr.media_type(),
            Self::Sonarr(_) => ServarrApp::Sonarr.media_type(),
            Self::Sportarr(_) => ServarrApp::Sportarr.media_type(),
        }
    }
}

impl ServarrConfigurationBody {
    /// Returns the app's configuration and the API key, if any, once WatchClub found the local root
    /// folder and parsed the URL. Doesn't call the app: the Instance Administrator chose the quality
    /// profile and root folder among those `servarr::test_connection` listed.
    async fn parse(
        self,
    ) -> Result<(ServarrConfiguration, Option<SecretString>), ServarrConfigurationError> {
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

        let configuration = ServarrConfiguration {
            url,
            quality_profile: self.quality_profile,
            root_folder_path: self.root_folder_path,
            local_root_folder_path,
        };
        Ok((configuration, self.api_key))
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

impl From<TestConnectionError> for ApiConnectionError {
    fn from(error: TestConnectionError) -> Self {
        match error {
            TestConnectionError::InvalidUrl => Self::InvalidServarrUrl,
            TestConnectionError::InvalidApiKey => Self::InvalidApiKey,
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

impl From<TestSavedConnectionError> for TestSavedSourceServarrConnectionRequestError {
    fn from(error: TestSavedConnectionError) -> Self {
        match error {
            TestSavedConnectionError::NotFound => Self::NotFound,
            TestSavedConnectionError::Connection(error) => Self::Connection(error.into()),
            TestSavedConnectionError::Internal(error) => Self::Internal(error),
        }
    }
}

impl IntoResponse for TestSavedSourceServarrConnectionRequestError {
    fn into_response(self) -> Response {
        let status = match self {
            Self::NotFound => StatusCode::NOT_FOUND,
            Self::Connection(error) => return error.into_response(),
            Self::Internal(error) => return ApiError::from(error).into_response(),
        };
        error::response(status, &self)
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
        let status = match self {
            Self::InvalidFilesystemConfiguration { .. }
            | Self::InvalidServarrConfiguration { .. } => StatusCode::UNPROCESSABLE_ENTITY,
            Self::Internal(error) => return ApiError::from(error).into_response(),
        };
        error::response(status, &self)
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

impl From<UpdateSourceError> for UpdateSourceRequestError {
    fn from(error: UpdateSourceError) -> Self {
        match error {
            UpdateSourceError::NotFound => Self::NotFound,
            UpdateSourceError::Internal(error) => Self::Internal(error),
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

impl From<DeleteSourceError> for DeleteSourceRequestError {
    fn from(error: DeleteSourceError) -> Self {
        match error {
            DeleteSourceError::NotFound => Self::NotFound,
            DeleteSourceError::Internal(error) => Self::Internal(error),
        }
    }
}

impl IntoResponse for DeleteSourceRequestError {
    fn into_response(self) -> Response {
        let status = match self {
            Self::NotFound => StatusCode::NOT_FOUND,
            Self::Internal(error) => return ApiError::from(error).into_response(),
        };
        error::response(status, &self)
    }
}
