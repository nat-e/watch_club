/**
 * Sources: where WatchClub imports Media Files from, which the Instance Administrator manages. A
 * Filesystem Source is a folder on the server; the others are a Radarr, Sonarr or Sportarr app.
 */
import {mutationOptions, queryOptions} from '@tanstack/react-query';
import * as api from '@watchclub/api';

/** The kind of place WatchClub imports Media Files from. */
export type SourceType = api.Source['type'];

/** The Source Types, in the order screens show them. */
export const SOURCE_TYPES: readonly SourceType[] = ['filesystem', 'radarr', 'sonarr', 'sportarr'];

/** The Media Types a Filesystem Source can bring, in the order screens list them. */
export const FILESYSTEM_MEDIA_TYPES: readonly api.MediaType[] = [
  'movie',
  'tv_show_episode',
  'sports_event',
];

/** A Filesystem Source: a folder on the server. */
export type FilesystemSource = Extract<api.Source, {type: 'filesystem'}>;

/** A Radarr, Sonarr or Sportarr Source. */
export type ServarrSource = Extract<api.Source, {type: api.ServarrApp}>;

/** Returns whether the Source is a Radarr, Sonarr or Sportarr app, rather than a folder. */
export function isServarrSource(source: api.Source): source is ServarrSource {
  return source.type !== 'filesystem';
}

/** The query of every Source, oldest first. */
export const sourcesQuery = queryOptions(api.listSourcesOptions());

/** The failure of a connection to an app that isn't at the URL, or that rejected the API key. */
export class ConnectionRefusedError extends Error {
  override readonly name = 'ConnectionRefusedError';

  constructor(override readonly cause: api.ConnectionError) {
    super(`the app refused the connection: ${cause.code}`);
  }
}

/** The failure of a save whose Filesystem Source has a folder that WatchClub can't read. */
export class InvalidFilesystemConfigurationError extends Error {
  override readonly name = 'InvalidFilesystemConfigurationError';

  constructor(override readonly cause: api.FolderError) {
    super(`the folder is invalid: ${cause.code}`);
  }
}

/**
 * The failure of a save whose Radarr, Sonarr or Sportarr Source Configuration has an error the
 * Instance Administrator can fix.
 */
export class InvalidServarrConfigurationError extends Error {
  override readonly name = 'InvalidServarrConfigurationError';

  constructor(override readonly cause: api.ServarrConfigurationError) {
    super(`the configuration is invalid: ${cause.part}`);
  }
}

/**
 * Tests the connection to a Radarr, Sonarr or Sportarr app, for a new Source: returns its quality
 * profiles and root folders once the server checked that the app is at the URL and takes the API
 * key. Throws a `ConnectionRefusedError` when it isn't or doesn't, and the API's error for other
 * failures. Named apart from the API client's `testServarrConnection`, which doesn't turn its
 * errors into these.
 */
export async function testAppConnection(
  connection: api.ServarrConnection,
): Promise<api.ServarrChoices> {
  const {data, error} = await api.testServarrConnection({body: connection});
  if (data) {
    return data;
  }
  throwConnectionError(error);
}

/**
 * Tests the connection to the app of the Radarr, Sonarr or Sportarr Source with `id`, with the
 * connection's API key, or else the Source's saved one when it has none. Returns and throws like
 * `testAppConnection`.
 */
export async function testSourceAppConnection(
  id: api.SourceId,
  connection: api.ServarrSourceConnection,
): Promise<api.ServarrChoices> {
  const {data, error} = await api.testServarrSourceConnection({path: {id}, body: connection});
  if (data) {
    return data;
  }
  throwConnectionError(error);
}

/**
 * Throws a `ConnectionRefusedError` when the app refused the connection, and the API's error for
 * other failures.
 */
function throwConnectionError(
  error:
    | api.TestServarrConnectionError
    | api.TestServarrSourceConnectionError
    | api.UnexpectedError,
): never {
  if (error instanceof api.UnexpectedError) {
    throw error;
  }
  switch (error.code) {
    case 'invalid_servarr_url':
    case 'invalid_api_key':
      throw new ConnectionRefusedError(error);
    case 'not_found':
    case 'invalid_request':
    case 'unauthorized':
    case 'forbidden':
    case 'internal_error':
      // The client turned it into an `ApiError`
      throw error;
  }
}

/** The Source Configuration to save, for the Source with `id`, or for a new one when there's none. */
interface SourceSave {
  configuration: api.SourceConfiguration;
  id?: api.SourceId;
}

/**
 * The mutation that creates a Source with the configuration, or gives it to the Source with `id`,
 * which keeps its type and Media Type, then refreshes the Sources. It throws an
 * `InvalidFilesystemConfigurationError` or an `InvalidServarrConfigurationError` when the
 * configuration is invalid, and the API's error for other failures.
 */
export const saveSourceMutation = mutationOptions({
  mutationFn: async ({configuration, id}: SourceSave, {client: queryClient}) => {
    const {data, error} =
      id === undefined
        ? await api.createSource({body: configuration})
        : await api.updateSource({path: {id}, body: configuration});
    if (data) {
      // Before answering, so that the Source shows once its form closes
      await queryClient.invalidateQueries({queryKey: sourcesQuery.queryKey});
      return data;
    }
    if (!(error instanceof api.UnexpectedError)) {
      if (error.code === 'invalid_filesystem_configuration') {
        throw new InvalidFilesystemConfigurationError(error.error);
      }
      if (error.code === 'invalid_servarr_configuration') {
        throw new InvalidServarrConfigurationError(error.error);
      }
    }
    throw error;
  },
});

/**
 * The mutation that deletes a Source, then refreshes the Sources. Named apart from the API client's
 * `deleteSourceMutation`, which doesn't refresh them.
 */
export const sourceDeletionMutation = mutationOptions({
  mutationFn: async (id: api.SourceId, {client: queryClient}) => {
    await api.deleteSource({path: {id}, throwOnError: true});
    await queryClient.invalidateQueries({queryKey: sourcesQuery.queryKey});
  },
});
