import {QueryClient} from '@tanstack/react-query';
import {type CurrentUser, client} from '@watchclub/api';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {
  currentUserQuery,
  forgetCurrentUser,
  setCurrentUser,
  updateCurrentUser,
} from '../../src/accounts/current-user';
import {createQueryClient} from '../../src/query-client';

// biome-ignore-start lint/style/useNamingConvention: the API uses snake_case field names
const ALICE: CurrentUser = {
  id: '0190c0de-0000-7000-8000-000000000001',
  is_instance_administrator: false,
  preferences: {
    locale: 'en-US',
    audio_language: 'original',
    subtitle_language: 'en',
    languages_without_subtitles: ['en'],
  },
  username: 'alice',
};
// biome-ignore-end lint/style/useNamingConvention: the API uses snake_case field names

const BOB: CurrentUser = {...ALICE, id: '0190c0de-0000-7000-8000-000000000002', username: 'bob'};

client.setConfig({baseUrl: 'https://watchclub.example.com'});

/** Answers that nobody is signed in, as the API does to a visitor or once a session ended. */
function refuseSessions() {
  vi.stubGlobal('fetch', () =>
    Promise.resolve(Response.json({code: 'unauthorized', message: 'Sign in'}, {status: 401})),
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('currentUserQuery', () => {
  it('tells a visitor that nobody is signed in, and leaves the other answers', async () => {
    refuseSessions();
    const queryClient = createQueryClient();
    await expect(queryClient.fetchQuery(currentUserQuery)).resolves.toBeNull();
    let answerInstance: (instance: string) => void = () => undefined;
    const instance = queryClient.fetchQuery({
      queryKey: ['instance'],
      queryFn: () =>
        new Promise<string>(resolve => {
          answerInstance = resolve;
        }),
    });

    await expect(queryClient.fetchQuery(currentUserQuery)).resolves.toBeNull();
    answerInstance('an instance');

    await expect(instance).resolves.toBe('an instance');
  });

  it('signs the User out once the API refuses their session', async () => {
    refuseSessions();
    const queryClient = createQueryClient();
    await setCurrentUser(queryClient, ALICE);

    await expect(queryClient.fetchQuery(currentUserQuery)).rejects.toThrow('Sign in');

    await vi.waitFor(() => {
      expect(queryClient.getQueryData(currentUserQuery.queryKey)).toBeNull();
    });
  });
});

describe('updateCurrentUser', () => {
  it('replaces the User with their newer copy', async () => {
    const queryClient = new QueryClient();
    await setCurrentUser(queryClient, ALICE);
    const frenchAlice: CurrentUser = {
      ...ALICE,
      preferences: {...ALICE.preferences, locale: 'fr-FR'},
    };

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
