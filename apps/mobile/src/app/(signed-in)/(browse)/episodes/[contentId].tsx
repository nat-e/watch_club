import {Stack, useLocalSearchParams} from 'expo-router';
import {Episodes} from '@/components/contents/episodes';

/**
 * A TV Show's Episodes by season, which its screen opens over itself, under the TV Show's title.
 */
export default function TvShowEpisodes() {
  const {contentId, title} = useLocalSearchParams<{contentId: string; title: string}>();
  return (
    <>
      <Stack.Screen options={{title}} />
      <Episodes contentId={contentId} />
    </>
  );
}
