import {Stack} from 'expo-router';
import {useTranslation} from 'react-i18next';

/** Browse's screens, under a header with their name. */
export default function BrowseLayout() {
  const {t} = useTranslation('core');

  return (
    <Stack>
      <Stack.Screen name="browse" options={{title: t($ => $.core.browse.title)}} />
    </Stack>
  );
}
