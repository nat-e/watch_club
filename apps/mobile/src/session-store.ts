/**
 * The Session outside React: who's signed in, and to which Instance. The Instance's URL and the
 * session token stay in the device's secure storage, and the API client sends every request with
 * them.
 */
import type {QueryClient} from '@tanstack/react-query';
import {type Credentials, client, getInstanceOptions, loginToken, logout} from '@watchclub/api';
import {forgetCurrentUser, setCurrentUser} from '@watchclub/core/accounts/current-user';
import {getBundleOrigin} from 'expo/internal/bundle-origin';
import * as secureStore from 'expo-secure-store';

/** The Instance the app talks to, and whether the app has a session token for it. */
export interface Session {
  /** The base URL of the Instance the User last signed in to, or null before they first do */
  readonly instanceUrl: string | null;
  /** Whether the app has a session token for the Instance, which the API may no longer accept */
  readonly hasToken: boolean;
}

const INSTANCE_URL_KEY = 'instance-url';

/** The time the app waits for the Instance's answer before giving up, as React Native sets none. */
const REQUEST_TIMEOUT_MS = 15_000;

/**
 * The store of the device's Session, which keeps it in secure storage and in the API client's
 * settings.
 */
export class SessionStore {
  private session?: Session = undefined;
  private readonly listeners = new Set<() => void>();

  constructor(private readonly queryClient: QueryClient) {}

  /** Returns the Session, or undefined until `restore` ends: a new object after each change. */
  getSession(): Session | undefined {
    return this.session;
  }

  /** Calls the listener after each change of the Session, until the returned function is called. */
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Restores the Session the app had when it last stopped, without what the device can't read. In
   * development, the Instance is the Expo dev server the app loaded from, which forwards the API to
   * the server running beside it.
   */
  async restore(): Promise<void> {
    const instanceUrl = getBundleOrigin() ?? (await readItem(INSTANCE_URL_KEY));
    const token = instanceUrl === null ? null : await readItem(tokenKey(instanceUrl));
    this.update(instanceUrl, token);
  }

  /**
   * Signs in to the Instance with the credentials, and keeps the User signed in on this device. The
   * app keeps one token: signing in to another Instance forgets the last one's.
   */
  async signIn(instanceUrl: string, credentials: Credentials): Promise<void> {
    const {data} = await loginToken({baseUrl: instanceUrl, body: credentials, throwOnError: true});
    const lastInstanceUrl = this.session?.instanceUrl ?? null;
    if (lastInstanceUrl !== null && lastInstanceUrl !== instanceUrl) {
      await secureStore.deleteItemAsync(tokenKey(lastInstanceUrl));
    }
    await secureStore.setItemAsync(INSTANCE_URL_KEY, instanceUrl);
    await secureStore.setItemAsync(tokenKey(instanceUrl), data.token);
    // The client before the User, as the screens that show the User ask the API again with its
    // token, and the User and the Instance before the listeners, so the app doesn't wait for the
    // API. Tried once, as the app says at once when it can't reach the Instance
    configureClient(instanceUrl, data.token);
    await setCurrentUser(this.queryClient, data.user);
    await this.queryClient.prefetchQuery({...getInstanceOptions(), retry: false});
    this.update(instanceUrl, data.token);
  }

  /** Ends the session, on this device even when the server can't be reached. */
  async signOut(): Promise<void> {
    await logout();
    await this.deleteToken();
    await forgetCurrentUser(this.queryClient);
  }

  /** Forgets the session token once the API refuses it, as when the session ended elsewhere. */
  async forgetToken(): Promise<void> {
    if (this.session?.hasToken) {
      await this.deleteToken();
    }
  }

  private async deleteToken() {
    const instanceUrl = this.session?.instanceUrl ?? null;
    if (instanceUrl !== null) {
      await secureStore.deleteItemAsync(tokenKey(instanceUrl));
    }
    this.update(instanceUrl, null);
  }

  /** Sends the API's requests to the Instance with the token, and tells the listeners. */
  private update(instanceUrl: string | null, token: string | null) {
    configureClient(instanceUrl, token);
    this.session = {instanceUrl, hasToken: token !== null};
    for (const listener of this.listeners) {
      listener();
    }
  }
}

/**
 * Returns the value of the key in secure storage, or null when there's none or the device can't
 * read it, as when Android lost the key that encrypts it. An unreadable value is deleted, so the
 * next start reads the storage cleanly.
 */
async function readItem(key: string): Promise<string | null> {
  try {
    return await secureStore.getItemAsync(key);
  } catch {
    // Starting signed out matters more than cleaning up, which the next start tries again
    await secureStore.deleteItemAsync(key).catch(() => undefined);
    return null;
  }
}

/** Sends the API's requests to the Instance, with the token. */
function configureClient(instanceUrl: string | null, token: string | null) {
  client.setConfig({
    baseUrl: instanceUrl ?? undefined,
    auth: scheme => (scheme.scheme === 'bearer' ? (token ?? undefined) : undefined),
    fetch: fetchWithTimeout,
  });
}

/** Sends the request, and gives up once the Instance doesn't answer within REQUEST_TIMEOUT_MS. */
function fetchWithTimeout(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
  const request = new Request(input, init);
  // The caller can still cancel it, as TanStack Query does once no screen needs the answer
  const signal = AbortSignal.any([request.signal, AbortSignal.timeout(REQUEST_TIMEOUT_MS)]);
  return fetch(request, {signal});
}

/**
 * Returns the key of the Instance's session token, in the characters secure storage allows. Each
 * Instance has its own key, so a token never goes to another Instance than the one that gave it.
 */
function tokenKey(instanceUrl: string): string {
  const hex = Array.from(new TextEncoder().encode(instanceUrl), byte =>
    byte.toString(16).padStart(2, '0'),
  );
  return `session-token-${hex.join('')}`;
}
