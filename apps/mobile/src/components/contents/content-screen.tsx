import {useQuery} from '@tanstack/react-query';
import {type ContentId, hasCode} from '@watchclub/api';
import {contentQuery} from '@watchclub/core/contents/content';
import {Stack, useLocalSearchParams} from 'expo-router';
import {useTranslation} from 'react-i18next';
import {ActivityIndicator, View} from 'react-native';
import {StatusScreen} from '@/components/layouts/status-screen';

/**
 * The screen of the Content whose TMDB ID is the route's `id`, with its title in the header. For
 * now, it only shows the title, until the Content pages are ported.
 */
export function ContentScreen({contentType}: {contentType: ContentId['content_type']}) {
  const {t} = useTranslation('core');
  const {id} = useLocalSearchParams<{id: string}>();
  // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
  const content = useQuery(contentQuery({content_type: contentType, tmdb_id: Number(id)}));

  if (content.isError) {
    return hasCode(content.error, 'not_found') ? (
      <StatusScreen
        title={t($ => $.core.notFound.title)}
        description={t($ => $.core.notFound.description)}
        actions={[]}
      />
    ) : (
      <StatusScreen
        title={t($ => $.core.search.failed)}
        description={t($ => $.core.errors.somethingWentWrong)}
        actions={[
          {
            label: t($ => $.core.search.tryAgain),
            onPress: () => {
              void content.refetch();
            },
          },
        ]}
      />
    );
  }
  return (
    <>
      <Stack.Screen options={{title: content.data?.title ?? ''}} />
      {content.isPending && (
        <View className="flex-1 items-center justify-center">
          <ActivityIndicator />
        </View>
      )}
    </>
  );
}
