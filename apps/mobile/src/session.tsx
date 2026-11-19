/**
 * Gives the screens the app's SessionStore, and the Session and signed-in User it holds.
 */
import {queryOptions, useQuery} from '@tanstack/react-query';
import {type CurrentUser, getInstanceOptions} from '@watchclub/api';
import {currentUserQuery} from '@watchclub/core/accounts/current-user';
import {
  createContext,
  type ReactNode,
  use,
  useCallback,
  useEffect,
  useSyncExternalStore,
} from 'react';
import type {Session, SessionStore} from '@/session-store';

/**
 * The query for the signed-in User, tried once: when the Instance doesn't answer, the app says so
 * at once, and asks again when the User taps to or comes back to the app.
 */
const SESSION_USER_QUERY = queryOptions({...currentUserQuery, retry: false});

/**
 * Returns the query for the Instance, whose name the signed-in screens show, tried once like the
 * User's.
 * Its key holds the Instance's URL, so it's created once the API client has it.
 */
function sessionInstanceQuery() {
  return queryOptions({...getInstanceOptions(), retry: false});
}

/** The Session, the signed-in User, and whether the app can reach the Instance. */
interface SessionState {
  session: Session;
  /** The signed-in User, or null when signed out or when the app can't reach the Instance */
  user: CurrentUser | null;
  /**
   * Whether the app has a session token, but can't reach the Instance to learn whose it is, or the
   * Instance Name
   */
  isInstanceUnreachable: boolean;
}

/** The store and its state, which the provider gives the screens once loaded. */
interface SessionContextValue extends SessionState {
  store: SessionStore;
}

const SessionContext = createContext<SessionContextValue | null>(null);

/**
 * The store and its state, for the screens inside it. It renders nothing until it knows who's
 * signed in and, for a User, the Instance Name, or that it can't reach the Instance to know, while
 * the splash screen shows.
 */
export function SessionProvider({store, children}: {store: SessionStore; children: ReactNode}) {
  // The same function on each render, or React subscribes again
  const subscribe = useCallback((listener: () => void) => store.subscribe(listener), [store]);
  const session = useSyncExternalStore(subscribe, () => store.getSession());
  const hasToken = session?.hasToken ?? false;
  const {data: user, errorUpdateCount: userErrorCount} = useQuery({
    ...SESSION_USER_QUERY,
    enabled: hasToken,
  });
  // At the same time as the User, rather than once the app knows them
  const {data: instance, errorUpdateCount: instanceErrorCount} = useQuery({
    ...sessionInstanceQuery(),
    enabled: hasToken,
  });
  // The Instance refused the token: the session ended, while the app was closed or since
  const isTokenRefused = hasToken && user === null;
  useEffect(() => {
    if (isTokenRefused) {
      void store.forgetToken();
    }
  }, [isTokenRefused, store]);

  // The app waits for the Instance to say who's signed in, then for the Instance Name that the
  // signed-in screens show. Once a request failed, it stays unreachable while it asks again
  const isAwaitingInstance =
    hasToken && (user === undefined || (user !== null && instance === undefined));
  const isInstanceUnreachable = isAwaitingInstance && userErrorCount + instanceErrorCount > 0;
  if (!session || (isAwaitingInstance && !isInstanceUnreachable)) {
    return null;
  }

  const value: SessionContextValue = {
    store,
    session,
    user: hasToken && !isAwaitingInstance ? (user ?? null) : null,
    isInstanceUnreachable,
  };
  return <SessionContext value={value}>{children}</SessionContext>;
}

/** Returns the Session and the signed-in User, and renders again when either changes. */
export function useSession(): SessionState {
  const {session, user, isInstanceUnreachable} = useSessionContext();
  return {session, user, isInstanceUnreachable};
}

/** Returns the store, which signs in and out and changes the Instance. */
export function useSessionStore(): SessionStore {
  return useSessionContext().store;
}

/**
 * Returns the function that asks the Instance again who's signed in and its name, once the app
 * couldn't reach it, and whether it's asking.
 */
export function useRetrySession(): {retry: () => void; isRetrying: boolean} {
  // Disabled, so they only ask when the User does
  const userQuery = useQuery({...SESSION_USER_QUERY, enabled: false});
  const instanceQuery = useQuery({...sessionInstanceQuery(), enabled: false});
  return {
    retry: () => {
      void userQuery.refetch();
      void instanceQuery.refetch();
    },
    isRetrying: userQuery.isFetching || instanceQuery.isFetching,
  };
}

function useSessionContext(): SessionContextValue {
  const value = use(SessionContext);
  if (!value) {
    throw new Error('the session hooks need a SessionProvider above them');
  }
  return value;
}
