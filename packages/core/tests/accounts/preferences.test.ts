import {MutationObserver, QueryClient} from '@tanstack/react-query';
import {type CurrentUser, client, type UserPreferences} from '@watchclub/api';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {currentUserQuery, forgetCurrentUser, setCurrentUser} from '../../src/accounts/current-user';
import {savePreferencesMutation} from '../../src/accounts/preferences';

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

client.setConfig({baseUrl: 'https://watchclub.example.com'});

/** Answers each request with the User and the preferences it sent, and returns those requests. */
function acceptPreferences(): UserPreferences[] {
  const received: UserPreferences[] = [];
  vi.stubGlobal('fetch', async (request: Request) => {
    const preferences: UserPreferences = await request.json();
    received.push(preferences);
    return Response.json({...ALICE, preferences});
  });
  return received;
}

afterEach(() => {
  vi.unstubAllGlobals();
});

const BOB: CurrentUser = {...ALICE, id: '0190c0de-0000-7000-8000-000000000002', username: 'bob'};

/** Saves the changes Alice made, as a screen of the app does. */
function save(queryClient: QueryClient, changes: Partial<UserPreferences>) {
  return new MutationObserver(queryClient, savePreferencesMutation).mutate({
    user: ALICE.id,
    changes,
  });
}

describe('savePreferencesMutation', () => {
  it('changes the preferences it is given, keeps the others and updates the User', async () => {
    const received = acceptPreferences();
    const queryClient = new QueryClient();
    await setCurrentUser(queryClient, ALICE);

    // biome-ignore lint/style/useNamingConvention: the API's field
    await save(queryClient, {subtitle_language: null});

    // biome-ignore lint/style/useNamingConvention: the API's field
    const expected: UserPreferences = {...ALICE.preferences, subtitle_language: null};
    expect(received).toEqual([expected]);
    expect(queryClient.getQueryData(currentUserQuery.queryKey)?.preferences).toEqual(expected);
  });

  it("keeps the changes of a save that hasn't ended when another starts", async () => {
    const received = acceptPreferences();
    const queryClient = new QueryClient();
    await setCurrentUser(queryClient, ALICE);

    await Promise.all([
      save(queryClient, {locale: 'fr-FR'}),
      // biome-ignore lint/style/useNamingConvention: the API's field
      save(queryClient, {audio_language: 'fr'}),
    ]);

    const expected: UserPreferences = {
      ...ALICE.preferences,
      locale: 'fr-FR',
      // biome-ignore lint/style/useNamingConvention: the API's field
      audio_language: 'fr',
    };
    expect(received.at(-1)).toEqual(expected);
    expect(queryClient.getQueryData(currentUserQuery.queryKey)?.preferences).toEqual(expected);
  });

  it("doesn't save the changes for the next User once the User signed out", async () => {
    const received = acceptPreferences();
    const queryClient = new QueryClient();
    await setCurrentUser(queryClient, ALICE);

    const first = save(queryClient, {locale: 'fr-FR'});
    // biome-ignore lint/style/useNamingConvention: the API's field
    const second = save(queryClient, {audio_language: 'fr'});
    await forgetCurrentUser(queryClient);
    await setCurrentUser(queryClient, BOB);

    await first;
    await expect(second).rejects.toThrow();
    expect(received).toHaveLength(1);
    expect(queryClient.getQueryData(currentUserQuery.queryKey)).toEqual(BOB);
  });
});
