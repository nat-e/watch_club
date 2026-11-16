import '../global.css';
import {focusManager, QueryClientProvider} from '@tanstack/react-query';
import {createQueryClient} from '@watchclub/core/query-client';
import {Stack} from 'expo-router';
import * as splashScreen from 'expo-splash-screen';
import {StatusBar} from 'expo-status-bar';
import {useEffect} from 'react';
import {AppState} from 'react-native';
import {useCSSVariable} from 'uniwind';
import {Localization} from '@/l10n';
import {SessionProvider, useSession} from '@/session';
import {SessionStore} from '@/session-store';

void splashScreen.preventAutoHideAsync();

// Once the session ends, the store forgets its token, and `Screens` shows signing in
const queryClient = createQueryClient({onSessionEnded: () => sessionStore.forgetToken()});
const sessionStore = new SessionStore(queryClient);
void sessionStore.restore();

// TanStack Query asks the API again when the app comes back to the foreground, as for a browser tab
focusManager.setEventListener(setFocused => {
  const subscription = AppState.addEventListener('change', state => {
    setFocused(state === 'active');
  });
  return () => {
    subscription.remove();
  };
});

export default function RootLayout() {
  return (
    <QueryClientProvider client={queryClient}>
      <SessionProvider store={sessionStore}>
        <Localization>
          <StatusBar style="light" />
          <Screens />
        </Localization>
      </SessionProvider>
    </QueryClientProvider>
  );
}

/**
 * Shows the screens for where the User is: signing in, signed in, or unable to reach the Instance.
 */
function Screens() {
  const {user, isInstanceUnreachable} = useSession();
  const background = useCSSVariable('--color-background');

  useEffect(() => {
    splashScreen.hide();
  }, []);

  return (
    <Stack
      screenOptions={{headerShown: false, contentStyle: {backgroundColor: String(background)}}}
    >
      <Stack.Protected guard={isInstanceUnreachable}>
        <Stack.Screen name="unreachable" />
      </Stack.Protected>
      <Stack.Protected guard={user === null && !isInstanceUnreachable}>
        <Stack.Screen name="sign-in" />
      </Stack.Protected>
      <Stack.Protected guard={user !== null}>
        <Stack.Screen name="(signed-in)" />
      </Stack.Protected>
    </Stack>
  );
}
