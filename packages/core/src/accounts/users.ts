/**
 * The Users of the Instance, which only the Instance Administrator lists and deletes.
 */
import {mutationOptions, queryOptions} from '@tanstack/react-query';
import {deleteUser, listUsersOptions, type UserId} from '@watchclub/api';

/** The query of every User, the first to join first. */
export const usersQuery = queryOptions(listUsersOptions());

/**
 * The mutation that deletes a User, which signs them out on every device, then refreshes the
 * Users, also when it fails, as the User may be gone already.
 */
export const deleteUserMutation = mutationOptions({
  mutationFn: async (userId: UserId) => {
    // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
    await deleteUser({path: {user_id: userId}, throwOnError: true});
  },
  onSettled: async (_result, _error, _userId, _onMutateResult, {client}) => {
    await client.invalidateQueries({queryKey: usersQuery.queryKey});
  },
});
