/**
 * The client that fetches the API's answers and caches them for every screen, with the rules both
 * apps follow when a request fails. Each app creates its own.
 */
import {MutationCache, QueryCache, QueryClient} from '@tanstack/react-query';
import {hasCode, UnexpectedError} from '@watchclub/api';
import {forgetCurrentUser} from './accounts/current-user';

/** The number of times a read is tried again, as many as TanStack Query tries by default. */
const MAX_RETRIES = 3;

/**
 * Returns the client that caches the API's answers. It tries a read again only when the API didn't
 * answer, such as when the network is down, as the API's answers don't change on a retry. Once the
 * session ends, the API refuses requests: the client then signs the User out.
 */
export function createQueryClient(): QueryClient {
  async function signOutWhenRefused(error: unknown) {
    if (hasCode(error, 'unauthorized')) {
      await forgetCurrentUser(queryClient);
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
