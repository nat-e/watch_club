/**
 * Invitations: the links the Instance Administrator shares so that new people can create their
 * account. Each change refreshes the list.
 */
import {mutationOptions, type QueryClient, queryOptions} from '@tanstack/react-query';
import {
  checkInvitationOptions,
  createInvitation,
  deleteInvitation,
  type InvitationId,
  listInvitationsOptions,
  updateInvitation,
} from '@watchclub/api';

/** The query of the Invitations that can still be redeemed, the oldest first. */
export const invitationsQuery = queryOptions(listInvitationsOptions());

/** Returns the query that tells whether the Invitation with this code can still be redeemed. */
export function invitationCheckQuery(code: string) {
  return queryOptions(checkInvitationOptions({query: {code}}));
}

/** New Max Uses for an Invitation. */
interface MaxUsesChange {
  invitation: InvitationId;
  /** The most Users it can create, or null for no limit */
  maxUses: number | null;
}

/**
 * The mutation that creates an Invitation that can create at most this many Users, or any number
 * when null.
 */
export const createInvitationMutation = mutationOptions({
  mutationFn: async (maxUses: number | null) => {
    // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
    const {data} = await createInvitation({body: {max_uses: maxUses}, throwOnError: true});
    return data;
  },
  onSuccess: (_invitation, _maxUses, _onMutateResult, {client}) => refreshInvitations(client),
});

/**
 * The mutation that changes the most Users an Invitation can create. It fails with
 * `max_uses_below_uses` when the Invitation created more Users already.
 */
export const changeMaxUsesMutation = mutationOptions({
  mutationFn: async ({invitation, maxUses}: MaxUsesChange) => {
    const {data} = await updateInvitation({
      // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
      path: {invitation_id: invitation},
      // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
      body: {max_uses: maxUses},
      throwOnError: true,
    });
    return data;
  },
  onSuccess: (_invitation, _change, _onMutateResult, {client}) => refreshInvitations(client),
});

/** The mutation that deletes an Invitation. The Users it created stay. */
export const deleteInvitationMutation = mutationOptions({
  mutationFn: async (invitation: InvitationId) => {
    // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
    await deleteInvitation({path: {invitation_id: invitation}, throwOnError: true});
  },
  onSuccess: (_result, _invitation, _onMutateResult, {client}) => refreshInvitations(client),
});

/**
 * Returns the Max Uses typed in a field: a whole number from 1, or null for no limit when the field
 * is blank. Returns undefined for anything else.
 */
export function parseMaxUses(text: string): number | null | undefined {
  const trimmed = text.trim();
  if (trimmed === '') {
    return null;
  }
  const maxUses = Number(trimmed);
  return /^\d+$/.test(trimmed) && maxUses >= 1 ? maxUses : undefined;
}

async function refreshInvitations(queryClient: QueryClient): Promise<void> {
  await queryClient.invalidateQueries({queryKey: invitationsQuery.queryKey});
}
