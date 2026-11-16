/**
 * Who's signed in, and to which WatchClub. The server's address and a session token for each server
 * stay in the device's secure storage, and the API client sends every request with them.
 */
import {useQuery, useQueryClient} from '@tanstack/react-query';
import {type AppSession, client, logout, type User} from '@watchclub/api';
import {currentUserQuery, signedIn, signedOut} from '@watchclub/core/accounts/session';
import {getBundleOrigin} from 'expo/internal/bundle-origin';
import * as secureStore from 'expo-secure-store';
import {createContext, type ReactNode, use, useEffect, useState} from 'react';

interface Session {
  /** The server's base URL, or null until the User picks one */
  server: string | null;
  /** The signed-in User, or null when signed out */
  user: User | null;
  /** Talks to this server from now on, as the User who last signed in to it, if any. */
  connect(server: string): Promise<void>;
  /** Forgets the server, so the User can pick another one, but keeps its session. */
  disconnect(): Promise<void>;
  /** Keeps the User signed in on this device with the session the API gave the app. */
  signIn(session: AppSession): Promise<void>;
  /** Ends the session, on this device even when the server can't be reached. */
  signOut(): Promise<void>;
}

/** The server the app talks to, and the session token it sends it. */
interface Connection {
  server: string | null;
  token: string | null;
}

const SERVER_KEY = 'server';

const SessionContext = createContext<Session | null>(null);

/** Renders nothing until it knows who's signed in, while the splash screen shows. */
export function SessionProvider({children}: {children: ReactNode}) {
  const queryClient = useQueryClient();
  const [connection, setConnection] = useState<Connection>();
  const token = connection?.token ?? null;
  const {data: user, isPending} = useQuery({...currentUserQuery, enabled: token !== null});

  function apply(next: Connection) {
    client.setConfig({
      baseUrl: next.server ?? undefined,
      auth: scheme => (scheme.scheme === 'bearer' ? (next.token ?? undefined) : undefined),
    });
    setConnection(next);
  }

  useEffect(() => {
    restore().then(next => {
      apply(next);
    });
  }, []);

  if (!connection || (token !== null && isPending)) {
    return null;
  }

  const saveToken = async (next: string | null) => {
    if (connection.server === null) {
      throw new Error('only the sign-in screen, which has a server, signs in and out');
    }
    await write(tokenKey(connection.server), next);
    apply({...connection, token: next});
  };

  const session: Session = {
    server: connection.server,
    user: token === null ? null : (user ?? null),
    connect: async server => {
      await secureStore.setItemAsync(SERVER_KEY, server);
      const token = await secureStore.getItemAsync(tokenKey(server));
      // Forgets the last server's answers: the new server's User then loads as when the app starts
      queryClient.clear();
      apply({server, token});
    },
    disconnect: async () => {
      await secureStore.deleteItemAsync(SERVER_KEY);
      apply({server: null, token: null});
      await signedOut(queryClient);
    },
    signIn: async ({token, user}) => {
      // The User first, so the token doesn't make the app wait for them
      await signedIn(queryClient, user);
      await saveToken(token);
    },
    signOut: async () => {
      await logout();
      await saveToken(null);
      await signedOut(queryClient);
    },
  };
  return <SessionContext value={session}>{children}</SessionContext>;
}

/**
 * Returns the server the app starts with and its session token. In development, the server is the
 * Expo dev server the app loaded from, which forwards the API to the server running beside it.
 */
async function restore(): Promise<Connection> {
  const server = getBundleOrigin() ?? (await secureStore.getItemAsync(SERVER_KEY));
  const token = server === null ? null : await secureStore.getItemAsync(tokenKey(server));
  return {server, token};
}

/** Returns the key of a server's session token, in the characters secure storage allows. */
function tokenKey(server: string): string {
  const hex = Array.from(new TextEncoder().encode(server), byte =>
    byte.toString(16).padStart(2, '0'),
  );
  return `session-token-${hex.join('')}`;
}

async function write(key: string, value: string | null) {
  if (value === null) {
    await secureStore.deleteItemAsync(key);
  } else {
    await secureStore.setItemAsync(key, value);
  }
}

export function useSession(): Session {
  const session = use(SessionContext);
  if (!session) {
    throw new Error('useSession needs a SessionProvider above it');
  }
  return session;
}
