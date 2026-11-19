import {QueryClient} from '@tanstack/react-query';
import {createMemoryHistory, createRouter} from '@tanstack/react-router';
import {type CurrentUser, getInstanceOptions, type Instance} from '@watchclub/api';
import {currentUserQuery} from '@watchclub/core/accounts/current-user';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {routeTree} from '@/routeTree.gen';

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

// biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
const ADMIN: CurrentUser = {...ALICE, is_instance_administrator: true, username: 'admin'};

const ORIGIN = 'https://watchclub.example.com';

beforeEach(() => {
  // Sign-in checks that the page to go back to is on this site
  vi.stubGlobal('location', new URL(ORIGIN));
});

afterEach(() => {
  vi.unstubAllGlobals();
});

/** Returns the address a visitor ends up at once they open `path`, signed in as `user`. */
async function open(path: string, user: CurrentUser | null): Promise<string> {
  const queryClient = new QueryClient();
  queryClient.setQueryData(currentUserQuery.queryKey, user);
  const instance: Instance = {
    name: 'WatchClub',
    version: '0.1.0',
    // biome-ignore-start lint/style/useNamingConvention: the API uses snake_case field names
    needs_setup: false,
    web_sentry_dsn: null,
    mobile_sentry_dsn: null,
    sentry_environment: 'production',
    // biome-ignore-end lint/style/useNamingConvention: the API uses snake_case field names
  };
  queryClient.setQueryData(getInstanceOptions().queryKey, instance);
  const router = createRouter({
    routeTree,
    context: {queryClient},
    history: createMemoryHistory({initialEntries: [path]}),
    // Loads as in a browser, which follows redirects, rather than as on a server, which only
    // reports them
    isServer: false,
    origin: ORIGIN,
  });
  await router.load();
  return router.state.location.href;
}

describe('the administration pages', () => {
  it('send visitors to sign in, and back afterwards', async () => {
    await expect(open('/admin/users', null)).resolves.toBe('/sign-in?return_to=%2Fadmin%2Fusers');
  });

  it('send Users other than the Instance Administrator home', async () => {
    await expect(open('/admin/users', ALICE)).resolves.toBe('/');
  });

  it('open for the Instance Administrator', async () => {
    await expect(open('/admin/users', ADMIN)).resolves.toBe('/admin/users');
  });
});
