import {Stack} from 'expo-router';
import {useTranslation} from 'react-i18next';

/** Browse's screens, under a header with their name, and the Content screens its search opens. */
export default function BrowseLayout() {
  const {t} = useTranslation('core');

  return (
    <Stack>
      <Stack.Screen name="browse" options={{title: t($ => $.core.browse.title)}} />
      <Stack.Screen name="movies/[id]" options={{title: ''}} />
      <Stack.Screen name="shows/[id]" options={{title: ''}} />
    </Stack>
  );
}
