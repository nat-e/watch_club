/**
 * The Users of the Instance, which only the Instance Administrator lists and deletes, and whose
 * Password Reset Links they create.
 */
import {mutationOptions, queryOptions} from '@tanstack/react-query';
import {createPasswordResetLink, deleteUser, listUsersOptions, type UserId} from '@watchclub/api';

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

/**
 * The mutation that creates a Password Reset Link for a User, which replaces their last one, and
 * returns the link's token.
 */
export const createPasswordResetLinkMutation = mutationOptions({
  mutationFn: async (userId: UserId) => {
    const {data} = await createPasswordResetLink({
      // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
      path: {user_id: userId},
      throwOnError: true,
    });
    return data.token;
  },
});
