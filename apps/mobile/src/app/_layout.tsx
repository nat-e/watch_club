import '../global.css';
import {QueryClientProvider} from '@tanstack/react-query';
import {createQueryClient} from '@watchclub/core/query-client';
import {Stack} from 'expo-router';
import * as splashScreen from 'expo-splash-screen';
import {StatusBar} from 'expo-status-bar';
import {useEffect} from 'react';
import {useCSSVariable} from 'uniwind';
import {Localization} from '@/l10n';
import {SessionProvider, useSession} from '@/session';

splashScreen.preventAutoHideAsync();

// Once the session ends, `Screens` shows signing in, as it follows the User
const queryClient = createQueryClient();

export default function RootLayout() {
  return (
    <QueryClientProvider client={queryClient}>
      <SessionProvider>
        <Localization>
          <StatusBar style="light" />
          <Screens />
        </Localization>
      </SessionProvider>
    </QueryClientProvider>
  );
}

/** Shows the screens for where the User is: picking their WatchClub, signing in, or signed in. */
function Screens() {
  const {server, user} = useSession();
  const background = useCSSVariable('--color-background');

  useEffect(() => {
    splashScreen.hide();
  }, []);

  return (
    <Stack
      screenOptions={{headerShown: false, contentStyle: {backgroundColor: String(background)}}}
    >
      <Stack.Protected guard={server === null}>
        <Stack.Screen name="connect" />
      </Stack.Protected>
      <Stack.Protected guard={server !== null && user === null}>
        <Stack.Screen name="sign-in" />
      </Stack.Protected>
      <Stack.Protected guard={user !== null}>
        <Stack.Screen name="(signed-in)" />
      </Stack.Protected>
    </Stack>
  );
}
