import {useQuery} from '@tanstack/react-query';
import {type ContentType, hasCode} from '@watchclub/api';
import {contentQuery} from '@watchclub/core/contents/content';
import {Stack, useLocalSearchParams} from 'expo-router';
import {useTranslation} from 'react-i18next';
import {ActivityIndicator, View} from 'react-native';
import {StatusScreen} from '@/components/layouts/status-screen';

/**
 * The screen of the Content whose External ID is the route's `id`, with its title in the header.
 * For now, it only shows the title, until the Content pages are ported.
 */
export function ContentScreen({contentType}: {contentType: ContentType}) {
  const {t} = useTranslation('core');
  const {id} = useLocalSearchParams<{id: string}>();
  // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
  const content = useQuery(contentQuery({content_type: contentType, external_id: id}));
  const messages = useMessages(contentType);

  if (hasCode(content.error, 'not_found')) {
    return <StatusScreen description={messages.notFound} actions={[]} />;
  }
  if (content.isError) {
    return (
      <StatusScreen
        description={messages.loadFailed}
        actions={[
          {
            label: t($ => $.core.controls.tryAgain),
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

/** Returns the screen's messages, whose words depend on the type of Content, such as its gender. */
function useMessages(contentType: ContentType): {notFound: string; loadFailed: string} {
  const {t} = useTranslation('core');
  switch (contentType) {
    case 'movie':
      return {
        notFound: t($ => $.core.contents.notFound, {context: 'movie'}),
        loadFailed: t($ => $.core.contents.loadFailed, {context: 'movie'}),
      };
    case 'tv_show':
      return {
        notFound: t($ => $.core.contents.notFound, {context: 'tvShow'}),
        loadFailed: t($ => $.core.contents.loadFailed, {context: 'tvShow'}),
      };
    case 'sports_event':
      return {
        notFound: t($ => $.core.contents.notFound, {context: 'sportsEvent'}),
        loadFailed: t($ => $.core.contents.loadFailed, {context: 'sportsEvent'}),
      };
    case 'book':
      return {
        notFound: t($ => $.core.contents.notFound, {context: 'book'}),
        loadFailed: t($ => $.core.contents.loadFailed, {context: 'book'}),
      };
  }
}
