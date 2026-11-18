import {QueryClient} from '@tanstack/react-query';
import type {CurrentUser} from '@watchclub/api';
import {currentUserQuery} from '@watchclub/core/accounts/current-user';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {SessionStore} from '@/session-store';

const {storage, bundle} = vi.hoisted(() => {
  const bundle: {origin: string | null} = {origin: null};
  return {storage: new Map<string, string>(), bundle};
});

vi.mock('expo-secure-store', () => ({
  getItemAsync: (key: string) => Promise.resolve(storage.get(key) ?? null),
  setItemAsync: (key: string, value: string) => {
    storage.set(key, value);
    return Promise.resolve();
  },
  deleteItemAsync: (key: string) => {
    storage.delete(key);
    return Promise.resolve();
  },
}));

vi.mock('expo/internal/bundle-origin', () => ({getBundleOrigin: () => bundle.origin}));

const INSTANCE = 'https://watchclub.example.com';
const OTHER_INSTANCE = 'https://other.example.com';
const DEV_SERVER = 'http://192.168.1.10:34767';

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

/** A request the API received: its URL and the session token it sent, if any. */
interface Received {
  url: string;
  token?: string;
}

/**
 * Answers the API as an Instance would, with a new token on each sign-in, and returns the requests
 * it receives. Once `down`, it doesn't answer.
 */
function fakeApi({down = false, password = 'passw0rd'} = {}): Received[] {
  const received: Received[] = [];
  let tokens = 0;
  vi.stubGlobal('fetch', async (request: Request) => {
    const url = new URL(request.url);
    const authorization = request.headers.get('Authorization');
    received.push({
      url: `${url.origin}${url.pathname}`,
      token: authorization?.slice('Bearer '.length),
    });
    if (down) {
      throw new TypeError('Failed to fetch');
    }
    switch (url.pathname) {
      case '/api/auth/login/token': {
        const body: unknown = await request.json();
        if (
          typeof body !== 'object' ||
          body === null ||
          !('password' in body) ||
          body.password !== password
        ) {
          return Response.json({code: 'wrong_credentials', message: 'Wrong'}, {status: 422});
        }
        tokens += 1;
        return Response.json({token: `token-${tokens}`, user: ALICE});
      }
      case '/api/auth/logout':
        return new Response(null, {status: 204});
      default:
        return Response.json({code: 'not_found', message: 'Not found'}, {status: 404});
    }
  });
  return received;
}

/** Returns a store restored as when the app starts, with the device's secure storage. */
async function startApp(queryClient = new QueryClient()): Promise<SessionStore> {
  const store = new SessionStore(queryClient);
  await store.restore();
  return store;
}

/** Returns a store signed in to the Instance as Alice. */
async function signedIn(queryClient = new QueryClient()): Promise<SessionStore> {
  const store = await startApp(queryClient);
  await store.signIn(INSTANCE, {username: 'alice', password: 'passw0rd'});
  return store;
}

afterEach(() => {
  storage.clear();
  bundle.origin = null;
  vi.unstubAllGlobals();
});

describe('SessionStore', () => {
  it('starts without an Instance', async () => {
    fakeApi();
    const store = await startApp();
    expect(store.getSession()).toEqual({instanceUrl: null, hasToken: false});
  });

  it('keeps the User signed in to the Instance when the app starts again', async () => {
    const received = fakeApi();
    await signedIn();

    const store = await startApp();
    expect(store.getSession()).toEqual({instanceUrl: INSTANCE, hasToken: true});
    await store.signOut();
    expect(received.at(-1)).toEqual({url: `${INSTANCE}/api/auth/logout`, token: 'token-1'});
  });

  it('caches the User before it has the token, so the app needs not ask for them', async () => {
    fakeApi();
    const queryClient = new QueryClient();
    const store = await startApp(queryClient);
    const cachedWhenSignedIn: unknown[] = [];
    store.subscribe(() => {
      if (store.getSession()?.hasToken) {
        cachedWhenSignedIn.push(queryClient.getQueryData(currentUserQuery.queryKey));
      }
    });

    await store.signIn(INSTANCE, {username: 'alice', password: 'passw0rd'});

    expect(cachedWhenSignedIn).toEqual([ALICE]);
  });

  it('keeps neither the Instance nor a token when the credentials are wrong', async () => {
    const received = fakeApi();
    const store = await startApp();

    await expect(
      store.signIn(INSTANCE, {username: 'alice', password: 'wrong'}),
    ).rejects.toMatchObject({code: 'wrong_credentials'});
    expect(received.at(-1)?.url).toBe(`${INSTANCE}/api/auth/login/token`);
    expect(store.getSession()).toEqual({instanceUrl: null, hasToken: false});
  });

  it('signs out on the device even when the server is down, and keeps the Instance', async () => {
    fakeApi();
    const queryClient = new QueryClient();
    const store = await signedIn(queryClient);
    fakeApi({down: true});

    await store.signOut();

    expect(store.getSession()).toEqual({instanceUrl: INSTANCE, hasToken: false});
    expect(queryClient.getQueryData(currentUserQuery.queryKey)).toBeNull();
    expect((await startApp()).getSession()).toEqual({instanceUrl: INSTANCE, hasToken: false});
  });

  it('forgets the token once the API refuses it', async () => {
    fakeApi();
    const store = await signedIn();

    await store.forgetToken();

    expect(store.getSession()).toEqual({instanceUrl: INSTANCE, hasToken: false});
    expect((await startApp()).getSession()).toEqual({instanceUrl: INSTANCE, hasToken: false});
  });

  it("forgets the last Instance's token on signing in to another one", async () => {
    const received = fakeApi();
    const store = await signedIn();

    await store.signIn(OTHER_INSTANCE, {username: 'alice', password: 'passw0rd'});
    await store.signOut();

    expect(received.at(-1)).toEqual({url: `${OTHER_INSTANCE}/api/auth/logout`, token: 'token-2'});
    bundle.origin = INSTANCE;
    expect((await startApp()).getSession()).toEqual({instanceUrl: INSTANCE, hasToken: false});
  });

  it("never sends an Instance's token to the dev server", async () => {
    fakeApi();
    await signedIn();
    bundle.origin = DEV_SERVER;

    const store = await startApp();

    expect(store.getSession()).toEqual({instanceUrl: DEV_SERVER, hasToken: false});
  });

  it('tells its listeners about each change until they unsubscribe', async () => {
    fakeApi();
    const store = await signedIn();
    const listener = vi.fn();
    const unsubscribe = store.subscribe(listener);

    await store.forgetToken();
    unsubscribe();
    await store.signIn(INSTANCE, {username: 'alice', password: 'passw0rd'});

    expect(listener).toHaveBeenCalledOnce();
  });
});
