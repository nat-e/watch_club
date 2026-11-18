import {useSearch, useTypedQuery} from '@watchclub/core/contents/search';
import {Stack} from 'expo-router';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {SearchResults} from '@/components/contents/search-results';

/**
 * Browse, where Users look through the Library, and search for any Content from its header's search
 * bar. Only search for now.
 */
export default function Browse() {
  const {t} = useTranslation('core');
  const [text, setText] = useState('');
  const query = useTypedQuery(text);
  const search = useSearch(query);

  return (
    <>
      <Stack.SearchBar
        placeholder={t($ => $.core.search.search)}
        onChangeText={event => {
          setText(event.nativeEvent.text);
        }}
        onCancelButtonPress={() => {
          setText('');
        }}
        hideWhenScrolling={false}
      />
      <SearchResults search={search} query={query.trim()} />
    </>
  );
}
