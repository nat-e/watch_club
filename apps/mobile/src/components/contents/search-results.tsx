import {Button, Column} from '@expo/ui';
import type {SearchResult, SearchScope} from '@watchclub/api';
import {useContentTypeNames} from '@watchclub/core/contents/content';
import {
  SEARCH_SCOPES,
  type Search,
  searchResultDetails,
  useSearchHint,
  useSearchScopeNames,
} from '@watchclub/core/contents/search';
import {router} from 'expo-router';
import type {ReactNode} from 'react';
import {useTranslation} from 'react-i18next';
import {ActivityIndicator, FlatList, Pressable, Text, View} from 'react-native';
import {Poster} from '@/components/contents/poster';
import {Host} from '@/components/host';
import {SegmentedControl} from '@/components/segmented-control';
import {Description, useAnnouncement} from '@/components/text';

/**
 * The scopes a search can look in, then its results, which load more as the User scrolls, or what
 * shows in their place: a hint before typing, a spinner, an error or no results. Each result opens
 * its Content's screen.
 */
export function SearchResults({
  search,
  query,
  scope,
  onScopeChange,
}: {
  search: Search;
  query: string;
  scope: SearchScope;
  onScopeChange: (scope: SearchScope) => void;
}) {
  return (
    <FlatList
      data={search.results}
      keyExtractor={result => `${result.content_type}/${result.external_id}`}
      renderItem={({item}) => <SearchResultRow result={item} />}
      onEndReached={search.loadMore}
      // A screen ahead, so the next page is there before the User reaches the end
      onEndReachedThreshold={1}
      ListHeaderComponent={<SearchScopes scope={scope} onScopeChange={onScopeChange} />}
      ListEmptyComponent={<SearchStatus search={search} scope={scope} query={query} />}
      contentContainerClassName="grow py-2"
      // Under the translucent header of iOS
      contentInsetAdjustmentBehavior="automatic"
      keyboardDismissMode="on-drag"
      keyboardShouldPersistTaps="handled"
    />
  );
}

/**
 * The control that picks the scope a search looks in, one per Metadata Provider, as their results
 * can't share one list.
 */
function SearchScopes({
  scope,
  onScopeChange,
}: {
  scope: SearchScope;
  onScopeChange: (scope: SearchScope) => void;
}) {
  const {t} = useTranslation('core');
  const scopeNames = useSearchScopeNames();
  return (
    <View className="px-4 py-2">
      <SegmentedControl
        label={t($ => $.core.search.scope)}
        segments={SEARCH_SCOPES.map(option => ({value: option, label: scopeNames[option]}))}
        value={scope}
        onChange={onScopeChange}
      />
    </View>
  );
}

/** A search result's poster, title, type, year and creators, which opens its Content's screen. */
function SearchResultRow({result}: {result: SearchResult}) {
  const contentTypeNames = useContentTypeNames();
  const facts = [contentTypeNames[result.content_type], ...searchResultDetails(result)].join(' · ');
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
          case 'book':
            router.push({pathname: '/books/[id]', params});
            break;
        }
      }}
      className="flex-row items-center gap-4 px-4 py-2 active:bg-pressed focus:bg-accent"
    >
      <Poster image={result.poster} width={56} />
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
function SearchStatus({search, scope, query}: {search: Search; scope: SearchScope; query: string}) {
  const {t} = useTranslation('core');
  const hint = useSearchHint(scope);
  const failed = t($ => $.core.search.failed);
  useAnnouncement(search.status === 'failed' ? failed : undefined);

  switch (search.status) {
    case 'idle':
      return <Message text={hint} />;
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
