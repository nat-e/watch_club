/**
 * The signed-in User, as both apps read it, or null once signed out.
 */
import {hashKey, type QueryClient, queryOptions, useSuspenseQuery} from '@tanstack/react-query';
import {getCurrentUser, getCurrentUserQueryKey, hasCode, type User} from '@watchclub/api';

/** The query for the signed-in User, which answers null when nobody is. */
export const currentUserQuery = queryOptions({
  queryKey: getCurrentUserQueryKey(),
  queryFn: async ({signal}): Promise<User | null> => {
    try {
      const {data} = await getCurrentUser({signal, throwOnError: true});
      return data;
    } catch (error) {
      if (hasCode(error, 'unauthorized')) {
        return null;
      }
      throw error;
    }
  },
});

/** Returns the signed-in User, for the screens that only Users see. */
export function useUser(): User {
  const {data: user} = useSuspenseQuery(currentUserQuery);
  if (!user) {
    throw new Error('only signed-in screens can read the User');
  }
  return user;
}

/** Records that the User signed in, so screens show them without asking the API again. */
export async function signedIn(queryClient: QueryClient, user: User): Promise<void> {
  // A request sent before signing in would answer that nobody is
  await queryClient.cancelQueries({queryKey: currentUserQuery.queryKey, exact: true});
  queryClient.setQueryData(currentUserQuery.queryKey, user);
}

/** Records that the User signed out, and forgets everything the API told them. */
export async function signedOut(queryClient: QueryClient): Promise<void> {
  await queryClient.cancelQueries({queryKey: currentUserQuery.queryKey, exact: true});
  // Updated rather than removed, so the screens that show the User see it
  queryClient.setQueryData(currentUserQuery.queryKey, null);
  const currentUserHash = hashKey(currentUserQuery.queryKey);
  queryClient.removeQueries({predicate: query => query.queryHash !== currentUserHash});
}
