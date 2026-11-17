import {QueryClient} from '@tanstack/react-query';
import {createMemoryHistory, createRouter} from '@tanstack/react-router';
import {getInstanceOptions, type Instance, type User} from '@watchclub/api';
import {currentUserQuery} from '@watchclub/core/accounts/current-user';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {routeTree} from '@/routeTree.gen';

const ALICE: User = {
  id: '0190c0de-0000-7000-8000-000000000001',
  // biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
  is_instance_administrator: false,
  locale: 'en-US',
  username: 'alice',
};

// biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
const ADMIN: User = {...ALICE, is_instance_administrator: true, username: 'admin'};

const ORIGIN = 'https://watchclub.example.com';

beforeEach(() => {
  // Sign-in checks that the page to go back to is on this site
  vi.stubGlobal('location', new URL(ORIGIN));
});

afterEach(() => {
  vi.unstubAllGlobals();
});

/** Returns the address a visitor ends up at once they open `path`, signed in as `user`. */
async function open(path: string, user: User | null): Promise<string> {
  const queryClient = new QueryClient();
  queryClient.setQueryData(currentUserQuery.queryKey, user);
  // biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
  const instance: Instance = {needs_setup: false, version: '0.1.0'};
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
