import {Button, Column} from '@expo/ui';
import type {SearchResult} from '@watchclub/api';
import {useContentTypeNames} from '@watchclub/core/contents/content';
import type {Search} from '@watchclub/core/contents/search';
import {router} from 'expo-router';
import type {ReactNode} from 'react';
import {useTranslation} from 'react-i18next';
import {ActivityIndicator, FlatList, Pressable, Text, View} from 'react-native';
import {Poster} from '@/components/contents/poster';
import {Host} from '@/components/host';
import {Description, useAnnouncement} from '@/components/text';

/**
 * The results of a search, which load more as the User scrolls, or what shows in their place: a
 * hint before typing, a spinner, an error or no results. Each result opens its Content's screen.
 */
export function SearchResults({search, query}: {search: Search; query: string}) {
  return (
    <FlatList
      data={search.results}
      keyExtractor={result => `${result.content_type}/${result.external_id}`}
      renderItem={({item}) => <SearchResultRow result={item} />}
      onEndReached={search.loadMore}
      // A screen ahead, so the next page is there before the User reaches the end
      onEndReachedThreshold={1}
      ListEmptyComponent={<SearchStatus search={search} query={query} />}
      contentContainerClassName="grow py-2"
      // Under the translucent header of iOS
      contentInsetAdjustmentBehavior="automatic"
      keyboardDismissMode="on-drag"
      keyboardShouldPersistTaps="handled"
    />
  );
}

/** A search result's poster, title, type and year, which opens its Content's screen. */
function SearchResultRow({result}: {result: SearchResult}) {
  const contentTypeNames = useContentTypeNames();
  const facts = [contentTypeNames[result.content_type], result.year]
    .filter(fact => fact !== null)
    .join(' · ');
  return (
    <Pressable
      accessibilityRole="button"
      onPress={() => {
        const params = {id: result.external_id};
        switch (result.content_type) {
          case 'movie':
            router.push({pathname: '/movies/[id]', params});
            break;
          case 'tv_show':
            router.push({pathname: '/shows/[id]', params});
            break;
        }
      }}
      className="flex-row items-center gap-4 px-4 py-2 active:bg-pressed focus:bg-accent"
    >
      <Poster path={result.poster_path} width={56} />
      <View className="flex-1 gap-1">
        <Text className="text-base font-semibold text-foreground" numberOfLines={2}>
          {result.title}
        </Text>
        <Text className="text-sm text-muted-foreground">{facts}</Text>
      </View>
    </Pressable>
  );
}

/** The hint, spinner, error or no results that a search shows in place of its results. */
function SearchStatus({search, query}: {search: Search; query: string}) {
  const {t} = useTranslation('core');
  const failed = t($ => $.core.search.failed);
  useAnnouncement(search.status === 'failed' ? failed : undefined);

  switch (search.status) {
    case 'idle':
      return <Message text={t($ => $.core.search.hint)} />;
    case 'loading':
      return (
        <View className="grow items-center justify-center p-6">
          <ActivityIndicator accessibilityLabel={t($ => $.core.search.searching)} />
        </View>
      );
    case 'failed':
      return (
        <Message text={failed}>
          <Button
            variant="outlined"
            label={t($ => $.core.controls.tryAgain)}
            onPress={search.retry}
          />
        </Message>
      );
    case 'done':
      return <Message text={t($ => $.core.search.nothingFound, {query})} />;
  }
}

/** A message in the middle of the screen, and the button that acts on it, if any. */
function Message({text, children}: {text: string; children?: ReactNode}) {
  return (
    <View className="grow justify-center p-6">
      <Host matchContents={{vertical: true}}>
        <Column alignment="center" spacing={16} style={{width: '100%'}}>
          <Description centered>{text}</Description>
          {children}
        </Column>
      </Host>
    </View>
  );
}
