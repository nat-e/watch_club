import {router, Stack} from 'expo-router';
import {SymbolView} from 'expo-symbols';
import {useTranslation} from 'react-i18next';
import {Pressable} from 'react-native';
import {useCSSVariable} from 'uniwind';

/**
 * Browse, where Users look through the Library, with the button that opens search in its header.
 * Only that button for now, until the Library is ported.
 */
export default function Browse() {
  return <Stack.Screen options={{headerRight: () => <SearchButton />}} />;
}

/** The magnifying glass that opens search. */
function SearchButton() {
  const {t} = useTranslation('core');
  const foreground = useCSSVariable('--color-foreground');
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={t($ => $.core.search.search)}
      hitSlop={12}
      onPress={() => {
        router.push('/search');
      }}
    >
      <SymbolView
        name={{ios: 'magnifyingglass', android: 'search'}}
        tintColor={String(foreground)}
        size={24}
      />
    </Pressable>
  );
}
