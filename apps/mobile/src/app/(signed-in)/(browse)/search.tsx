import {DEFAULT_SEARCH_SCOPE, useSearch, useTypedQuery} from '@watchclub/core/contents/search';
import {type NativeStackNavigationProp, router, Stack, useNavigation} from 'expo-router';
import {useEffect, useRef, useState} from 'react';
import {useTranslation} from 'react-i18next';
import type {SearchBarCommands} from 'react-native-screens';
import {SearchResults} from '@/components/contents/search-results';
import {useHiddenTabBar} from '@/tab-bar';

/**
 * Search, over the whole screen: the search bar in its header, which has the keyboard as it opens,
 * then the scopes and the results. Closing the search bar closes search.
 */
export default function Search() {
  const {t} = useTranslation('core');
  const navigation = useNavigation<NativeStackNavigationProp<{search: undefined}>>();
  const searchBar = useRef<SearchBarCommands>(null);
  const [text, setText] = useState('');
  const [scope, setScope] = useState(DEFAULT_SEARCH_SCOPE);
  const query = useTypedQuery(text);
  const search = useSearch(query, scope);
  useHiddenTabBar();

  // iOS has no `autoFocus`, and can only focus the search bar once the screen shows. Only the first
  // time, so the keyboard stays closed when the User comes back from a result
  useEffect(() => {
    const unsubscribe = navigation.addListener('transitionEnd', () => {
      searchBar.current?.focus();
      unsubscribe();
    });
    return unsubscribe;
  }, [navigation]);

  return (
    <>
      <Stack.SearchBar
        ref={searchBar}
        autoFocus
        placeholder={t($ => $.core.search.search)}
        onChangeText={event => {
          setText(event.nativeEvent.text);
        }}
        onCancelButtonPress={() => {
          router.back();
        }}
        onClose={() => {
          router.back();
        }}
        hideWhenScrolling={false}
      />
      <SearchResults search={search} query={query.trim()} scope={scope} onScopeChange={setScope} />
    </>
  );
}
