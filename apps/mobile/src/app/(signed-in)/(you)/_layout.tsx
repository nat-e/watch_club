import {Stack} from 'expo-router';
import {useTranslation} from 'react-i18next';

// A link to My Requests or Settings, or to one of Settings' screens, opens You below it, for the
// back button
// biome-ignore lint/style/useNamingConvention: Expo Router reads this name
export const unstable_settings = {anchor: 'you'};

/**
 * You, and the pages that have no tab, which open over it under a header with their name, as do the
 * screens of Settings over Settings.
 */
export default function YouLayout() {
  const {t} = useTranslation(['mobile', 'core']);

  return (
    <Stack>
      <Stack.Screen name="you" options={{title: t($ => $.mobile.you.title)}} />
      <Stack.Screen name="my-requests" options={{title: t($ => $.core.myRequests.title)}} />
      <Stack.Screen name="settings/index" options={{title: t($ => $.core.settings.title)}} />
      <Stack.Screen name="settings/language" options={{title: t($ => $.core.settings.language)}} />
      <Stack.Screen name="settings/audio" options={{title: t($ => $.core.settings.audio)}} />
      <Stack.Screen name="settings/about" options={{title: t($ => $.core.settings.about)}} />
      <Stack.Screen
        name="settings/subtitles"
        options={{title: t($ => $.core.settings.subtitles)}}
      />
      {/* It edits a draft that its Done or Save saves, so it opens over Settings */}
      <Stack.Screen
        name="settings/languages-without-subtitles"
        options={{title: t($ => $.core.settings.languagesWithoutSubtitles), presentation: 'modal'}}
      />
    </Stack>
  );
}
