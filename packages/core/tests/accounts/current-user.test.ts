import {QueryClient} from '@tanstack/react-query';
import type {User} from '@watchclub/api';
import {describe, expect, it} from 'vitest';
import {
  currentUserQuery,
  forgetCurrentUser,
  setCurrentUser,
  updateCurrentUser,
} from '../../src/accounts/current-user';

const ALICE: User = {
  id: '0190c0de-0000-7000-8000-000000000001',
  // biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
  is_instance_administrator: false,
  locale: 'en-US',
  username: 'alice',
};

const BOB: User = {...ALICE, id: '0190c0de-0000-7000-8000-000000000002', username: 'bob'};

describe('updateCurrentUser', () => {
  it('replaces the User with their newer copy', async () => {
    const queryClient = new QueryClient();
    await setCurrentUser(queryClient, ALICE);
    const frenchAlice: User = {...ALICE, locale: 'fr-FR'};

    await updateCurrentUser(queryClient, frenchAlice);

    expect(queryClient.getQueryData(currentUserQuery.queryKey)).toEqual(frenchAlice);
  });

  it('leaves nobody signed in once the User signed out', async () => {
    const queryClient = new QueryClient();
    await setCurrentUser(queryClient, ALICE);
    await forgetCurrentUser(queryClient);

    await updateCurrentUser(queryClient, ALICE);

    expect(queryClient.getQueryData(currentUserQuery.queryKey)).toBeNull();
  });

  it('leaves the User who signed in since', async () => {
    const queryClient = new QueryClient();
    await setCurrentUser(queryClient, ALICE);
    await forgetCurrentUser(queryClient);
    await setCurrentUser(queryClient, BOB);

    await updateCurrentUser(queryClient, ALICE);

    expect(queryClient.getQueryData(currentUserQuery.queryKey)).toEqual(BOB);
  });
});
