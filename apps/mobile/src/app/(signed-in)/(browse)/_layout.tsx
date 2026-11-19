import {Stack} from 'expo-router';
import {useTranslation} from 'react-i18next';

/**
 * Browse's screens, under a header with their name: Browse, search, which fades in over the whole
 * screen, the Content screens it opens, and a TV Show's Episodes, which open over its screen.
 */
export default function BrowseLayout() {
  const {t} = useTranslation('core');

  return (
    <Stack>
      <Stack.Screen name="browse" options={{title: t($ => $.core.browse.title)}} />
      <Stack.Screen
        name="search"
        options={{title: t($ => $.core.search.search), animation: 'fade'}}
      />
      <Stack.Screen name="movies/[id]" options={{title: ''}} />
      <Stack.Screen name="shows/[id]" options={{title: ''}} />
      <Stack.Screen name="sports/[id]" options={{title: ''}} />
      <Stack.Screen name="books/[id]" options={{title: ''}} />
      <Stack.Screen name="episodes/[contentId]" options={{title: '', presentation: 'modal'}} />
    </Stack>
  );
}
