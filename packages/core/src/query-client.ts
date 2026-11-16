/**
 * The client that fetches the API's answers and caches them for every screen, with the rules both
 * apps follow when a request fails. Each app creates its own, as each one adds its platform's parts.
 */
import {MutationCache, QueryCache, QueryClient} from '@tanstack/react-query';
import {hasCode, UnexpectedError} from '@watchclub/api';
import {signedOut} from './accounts/session';

/** The number of times a read is tried again, as many as TanStack Query tries by default. */
const MAX_RETRIES = 3;

/** The parts of the query client each app adds for its platform. */
interface QueryClientOptions {
  /**
   * The app's step once the session ends, as it expires or ends elsewhere, and the client signed
   * the User out, such as asking them to sign in again
   */
  onSessionEnded?: () => Promise<void>;
}

/**
 * Returns the client that caches the API's answers. It tries a read again only when the API didn't
 * answer, such as when the network is down, as the API's answers don't change on a retry. Once the
 * session ends, the API refuses requests: the client then signs the User out.
 */
export function createQueryClient({onSessionEnded}: QueryClientOptions = {}): QueryClient {
  async function signOutWhenRefused(error: unknown) {
    if (hasCode(error, 'unauthorized')) {
      await signedOut(queryClient);
      await onSessionEnded?.();
    }
  }

  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: (failureCount, error) =>
          error instanceof UnexpectedError && failureCount < MAX_RETRIES,
      },
    },
    queryCache: new QueryCache({onError: signOutWhenRefused}),
    mutationCache: new MutationCache({onError: signOutWhenRefused}),
  });
  return queryClient;
}
