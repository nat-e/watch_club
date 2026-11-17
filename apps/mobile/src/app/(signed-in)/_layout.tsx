import {Stack} from 'expo-router';
import {useTranslation} from 'react-i18next';

// A link that opens another screen first opens the tabs below it, for the back button
// biome-ignore lint/style/useNamingConvention: Expo Router reads this name
export const unstable_settings = {anchor: '(tabs)'};

/** The screens of signed-in Users: the tabs, and the pages that open over them. */
export default function SignedInLayout() {
  const {t} = useTranslation('core');

  return (
    // The tabs' title changes with the tab, so the back button shows none
    <Stack screenOptions={{headerBackButtonDisplayMode: 'minimal'}}>
      <Stack.Screen name="(tabs)" options={{headerShown: false}} />
      <Stack.Screen name="my-requests" options={{title: t($ => $.core.myRequests.title)}} />
      <Stack.Screen name="settings" options={{title: t($ => $.core.settings.title)}} />
    </Stack>
  );
}
