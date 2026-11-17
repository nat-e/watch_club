import {Stack} from 'expo-router';
import {useTranslation} from 'react-i18next';

/** The Playlists' screens, under a header with their name. */
export default function PlaylistsLayout() {
  const {t} = useTranslation('core');

  return (
    <Stack>
      <Stack.Screen name="playlists" options={{title: t($ => $.core.playlists.title)}} />
    </Stack>
  );
}
