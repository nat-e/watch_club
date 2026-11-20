/**
 * The Users of the Instance, which every User can see, and deleting them, which only the Instance
 * Administrator can do.
 */
import {mutationOptions, queryOptions} from '@tanstack/react-query';
import {deleteUser, listUsersOptions, type UserId} from '@watchclub/api';

/** The query of every User, the first to join first. */
export const usersQuery = queryOptions(listUsersOptions());

/**
 * The mutation that deletes a User, which signs them out on every device, then refreshes the
 * Users.
 */
export const deleteUserMutation = mutationOptions({
  mutationFn: async (user: UserId) => {
    // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
    await deleteUser({path: {user_id: user}, throwOnError: true});
  },
  onSuccess: async (_result, _user, _onMutateResult, {client}) => {
    await client.invalidateQueries({queryKey: usersQuery.queryKey});
  },
});
