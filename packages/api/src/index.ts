/**
 * The client of WatchClub's API, generated from the OpenAPI document of `apps/server`. Run
 * `pnpm generate` after changing the API.
 */
import {client} from './generated/client.gen';

export * from './generated';
export * from './generated/@tanstack/react-query.gen';
export {client};

/** The body of every error the API sends: a code that says which failure it is, and a message. */
interface ErrorBody {
  code: string;
  message: string;
}

/**
 * An error the API sent. It holds the body's code, message and details, such as the problems with
 * each field, so it matches the error type of the request that failed.
 */
export class ApiError extends Error {
  override readonly name = 'ApiError';
  readonly code: string;

  constructor(body: ErrorBody) {
    super(body.message);
    this.code = body.code;
    Object.assign(this, body);
  }
}

/** A failure the API didn't describe, such as a network error or a proxy's error page. */
export class UnexpectedError extends Error {
  override readonly name = 'UnexpectedError';

  constructor(
    options: ErrorOptions,
    readonly status?: number,
  ) {
    super(status === undefined ? 'The API sent no answer' : `The API answered ${status}`, options);
  }
}

/** Returns whether `error` is the API's error with this code, such as `unauthorized`. */
export function hasCode<Code extends string>(
  error: unknown,
  code: Code,
): error is ApiError & {code: Code} {
  return error instanceof ApiError && error.code === code;
}

function isErrorBody(value: unknown): value is ErrorBody {
  return (
    typeof value === 'object' &&
    value !== null &&
    'code' in value &&
    typeof value.code === 'string' &&
    'message' in value &&
    typeof value.message === 'string'
  );
}

// The generated client throws the API's error body, which each request's error type describes.
// Other failures don't match that type, so they become an `UnexpectedError`
client.interceptors.error.use((error, response) =>
  isErrorBody(error) ? new ApiError(error) : new UnexpectedError({cause: error}, response?.status),
);
