/**
 * The current User, who's signed in, as both apps read and change it.
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
export function useCurrentUser(): User {
  const {data: user} = useSuspenseQuery(currentUserQuery);
  if (!user) {
    throw new Error('only signed-in screens can read the User');
  }
  return user;
}

/** Makes `user` the current User, so screens show them without asking the API again. */
export async function setCurrentUser(queryClient: QueryClient, user: User): Promise<void> {
  // A request sent earlier would overwrite `user` with an older answer, such as that nobody is
  // signed in
  await queryClient.cancelQueries({queryKey: currentUserQuery.queryKey, exact: true});
  queryClient.setQueryData(currentUserQuery.queryKey, user);
}

/**
 * Replaces the current User with a newer copy of them from the API, such as after they change
 * their User Preferences. Does nothing once they've signed out, as the answer can arrive later.
 */
export async function updateCurrentUser(queryClient: QueryClient, user: User): Promise<void> {
  // A request sent earlier would overwrite `user` with an older answer
  await queryClient.cancelQueries({queryKey: currentUserQuery.queryKey, exact: true});
  queryClient.setQueryData(currentUserQuery.queryKey, current =>
    current?.id === user.id ? user : current,
  );
}

/** Makes nobody the current User, and forgets everything the API told the last one. */
export async function forgetCurrentUser(queryClient: QueryClient): Promise<void> {
  // Before waiting, so it doesn't cancel the requests the app sends meanwhile, such as the next
  // page's
  const currentUserHash = hashKey(currentUserQuery.queryKey);
  queryClient.removeQueries({predicate: query => query.queryHash !== currentUserHash});
  await queryClient.cancelQueries({queryKey: currentUserQuery.queryKey, exact: true});
  // Updated rather than removed, so the screens that show the User see it
  queryClient.setQueryData(currentUserQuery.queryKey, null);
}
