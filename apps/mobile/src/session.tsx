/**
 * Gives the screens the app's SessionStore, and the Session and signed-in User it holds.
 */
import {useQuery} from '@tanstack/react-query';
import type {User} from '@watchclub/api';
import {currentUserQuery} from '@watchclub/core/accounts/current-user';
import {createContext, type ReactNode, use, useCallback, useSyncExternalStore} from 'react';
import type {Session, SessionStore} from '@/session-store';

/** The Session, and the signed-in User, or null when signed out. */
interface SessionState {
  session: Session;
  user: User | null;
}

/** What the provider gives the screens: the store, and its state once loaded. */
interface SessionContextValue extends SessionState {
  store: SessionStore;
}

const SessionContext = createContext<SessionContextValue | null>(null);

/**
 * Gives the screens inside it the store and its state. Renders nothing until it knows who's signed
 * in, while the splash screen shows.
 */
export function SessionProvider({store, children}: {store: SessionStore; children: ReactNode}) {
  // The same function on each render, or React subscribes again
  const subscribe = useCallback((listener: () => void) => store.subscribe(listener), [store]);
  const session = useSyncExternalStore(subscribe, () => store.getSession());
  const hasToken = session?.hasToken ?? false;
  const {data: user, isPending} = useQuery({...currentUserQuery, enabled: hasToken});
  if (!session || (hasToken && isPending)) {
    return null;
  }
  const value: SessionContextValue = {store, session, user: hasToken ? (user ?? null) : null};
  return <SessionContext value={value}>{children}</SessionContext>;
}

/** Returns the Session and the signed-in User, and renders again when either changes. */
export function useSession(): SessionState {
  const {session, user} = useSessionContext();
  return {session, user};
}

/** Returns the store, which signs in and out and changes the Instance. */
export function useSessionStore(): SessionStore {
  return useSessionContext().store;
}

function useSessionContext(): SessionContextValue {
  const value = use(SessionContext);
  if (!value) {
    throw new Error('the session hooks need a SessionProvider above them');
  }
  return value;
}
