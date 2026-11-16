import type {QueryClient} from '@tanstack/react-query';
import {ApiError, UnexpectedError, type User} from '@watchclub/api';
import {describe, expect, it, vi} from 'vitest';
import {currentUserQuery} from '../src/accounts/current-user';
import {createQueryClient} from '../src/query-client';

const ALICE: User = {
  id: '0190c0de-0000-7000-8000-000000000001',
  // biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
  is_instance_administrator: false,
  locale: 'en-US',
  username: 'alice',
};

const SESSION_ENDED = new ApiError({code: 'unauthorized', message: 'Sign in'});

/** Returns a client with Alice signed in and her Inbox cached. */
function signedInClient(): QueryClient {
  const queryClient = createQueryClient();
  queryClient.setQueryData(currentUserQuery.queryKey, ALICE);
  queryClient.setQueryData(['inbox'], ['a conversation']);
  return queryClient;
}

describe('createQueryClient', () => {
  it('signs the User out once the API refuses a read', async () => {
    const queryClient = signedInClient();

    const read = queryClient.fetchQuery({
      queryKey: ['conversation'],
      queryFn: () => Promise.reject(SESSION_ENDED),
    });

    await expect(read).rejects.toThrow('Sign in');
    await vi.waitFor(() => {
      expect(queryClient.getQueryData(currentUserQuery.queryKey)).toBeNull();
    });
    expect(queryClient.getQueryData<string[]>(['inbox'])).toBeUndefined();
  });

  it('signs the User out once the API refuses a change', async () => {
    const queryClient = signedInClient();

    const change = queryClient
      .getMutationCache()
      .build(queryClient, {mutationFn: () => Promise.reject(SESSION_ENDED)})
      .execute(undefined);

    await expect(change).rejects.toThrow('Sign in');
    await vi.waitFor(() => {
      expect(queryClient.getQueryData(currentUserQuery.queryKey)).toBeNull();
    });
  });

  it('keeps the User signed in when a read fails otherwise', async () => {
    const queryClient = signedInClient();

    const read = queryClient.fetchQuery({
      queryKey: ['conversation'],
      queryFn: () => Promise.reject(new ApiError({code: 'not_found', message: 'Not found'})),
    });

    await expect(read).rejects.toThrow('Not found');
    expect(queryClient.getQueryData(currentUserQuery.queryKey)).toEqual(ALICE);
  });

  it('tries a read again when the API did not answer', async () => {
    const queryClient = createQueryClient();
    const queryFn = vi
      .fn<() => Promise<string>>()
      .mockRejectedValueOnce(new UnexpectedError({cause: new TypeError('Failed to fetch')}))
      .mockRejectedValueOnce(new UnexpectedError({}, 502))
      .mockResolvedValue('a conversation');

    const read = queryClient.fetchQuery({queryKey: ['conversation'], queryFn, retryDelay: 0});

    await expect(read).resolves.toBe('a conversation');
    expect(queryFn).toHaveBeenCalledTimes(3);
  });

  it('gives up on a read the API did not answer after three more tries', async () => {
    const queryClient = createQueryClient();
    const queryFn = vi.fn(() => Promise.reject(new UnexpectedError({}, 502)));

    const read = queryClient.fetchQuery({queryKey: ['conversation'], queryFn, retryDelay: 0});

    await expect(read).rejects.toThrow(UnexpectedError);
    expect(queryFn).toHaveBeenCalledTimes(4);
  });

  it('does not try a read again when the API answered', async () => {
    const queryClient = createQueryClient();
    const queryFn = vi.fn(() =>
      Promise.reject(new ApiError({code: 'not_found', message: 'Not found'})),
    );

    const read = queryClient.fetchQuery({queryKey: ['conversation'], queryFn, retryDelay: 0});

    await expect(read).rejects.toThrow('Not found');
    expect(queryFn).toHaveBeenCalledOnce();
  });
});
