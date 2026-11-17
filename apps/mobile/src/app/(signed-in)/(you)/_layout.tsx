import {Stack} from 'expo-router';
import {useTranslation} from 'react-i18next';

// A link to My Requests or Settings opens You below it, for the back button
// biome-ignore lint/style/useNamingConvention: Expo Router reads this name
export const unstable_settings = {anchor: 'you'};

/** You, and the pages that have no tab, which open over it under a header with their name. */
export default function YouLayout() {
  const {t} = useTranslation(['mobile', 'core']);

  return (
    <Stack>
      <Stack.Screen name="you" options={{title: t($ => $.mobile.you.title)}} />
      <Stack.Screen name="my-requests" options={{title: t($ => $.core.myRequests.title)}} />
      <Stack.Screen name="settings" options={{title: t($ => $.core.settings.title)}} />
    </Stack>
  );
}
