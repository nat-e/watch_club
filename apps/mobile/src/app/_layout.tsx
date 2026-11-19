import '../global.css';
import {Oxanium_600SemiBold} from '@expo-google-fonts/oxanium/600SemiBold';
import * as sentry from '@sentry/react-native';
import {focusManager, QueryClientProvider} from '@tanstack/react-query';
import {createQueryClient} from '@watchclub/core/query-client';
import {useFonts} from 'expo-font';
import {DarkTheme, Stack, type Theme, ThemeProvider} from 'expo-router';
import * as splashScreen from 'expo-splash-screen';
import {StatusBar} from 'expo-status-bar';
import {useEffect, useMemo} from 'react';
import {AppState} from 'react-native';
import {GestureHandlerRootView} from 'react-native-gesture-handler';
import {useCSSVariable} from 'uniwind';
import {Toaster} from '@/components/toaster';
import {Localization} from '@/l10n';
import {reportToInstance, startSentry} from '@/sentry';
import {SessionProvider, useSession} from '@/session';
import {SessionStore} from '@/session-store';

void startSentry();
void splashScreen.preventAutoHideAsync();

const queryClient = createQueryClient();
const sessionStore = new SessionStore(queryClient);
// Sentry reports to the Session's Instance, which changes when the User signs in to another one
sessionStore.subscribe(() => {
  void reportToInstance(sessionStore.getSession()?.instanceUrl ?? null);
});
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

export default sentry.wrap(RootLayout);

function RootLayout() {
  // The headings' font, as on the web app. The splash screen stays until it loads, and the
  // headings fall back to the system's font if it fails
  // biome-ignore lint/style/useNamingConvention: the font's name, which `font-heading` uses
  const [isFontLoaded, fontError] = useFonts({Oxanium_600SemiBold});
  if (!isFontLoaded && fontError === null) {
    return null;
  }

  return (
    // Gesture Handler's root lets the User swipe toasts away
    <GestureHandlerRootView style={{flex: 1}}>
      <QueryClientProvider client={queryClient}>
        <SessionProvider store={sessionStore}>
          <Localization>
            <StatusBar style="light" />
            <Screens />
            <Toaster />
          </Localization>
        </SessionProvider>
      </QueryClientProvider>
    </GestureHandlerRootView>
  );
}

/** The screens for where the User is: signing in, signed in, or unable to reach the Instance. */
function Screens() {
  const {user, isInstanceUnreachable} = useSession();

  useEffect(() => {
    splashScreen.hide();
  }, []);

  return (
    <ThemeProvider value={useNavigationTheme()}>
      <Stack screenOptions={{headerShown: false}}>
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
    </ThemeProvider>
  );
}

/** Returns the app's colors as a theme for the navigators' headers and screens. */
function useNavigationTheme(): Theme {
  const [background, card, foreground, border, destructive] = useCSSVariable([
    '--color-background',
    '--color-card',
    '--color-foreground',
    '--color-border',
    '--color-destructive',
  ]);
  return useMemo(
    () => ({
      ...DarkTheme,
      colors: {
        // Back buttons take the text's color rather than a brand color
        primary: String(foreground),
        background: String(background),
        card: String(card),
        text: String(foreground),
        border: String(border),
        notification: String(destructive),
      },
    }),
    [background, card, foreground, border, destructive],
  );
}
