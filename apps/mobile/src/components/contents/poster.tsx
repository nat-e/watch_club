import {posterUrl} from '@watchclub/core/contents/content';
import {Image} from 'expo-image';
import {View} from 'react-native';

/**
 * A Content's poster from TMDB, `width` points wide, or a placeholder when it has none. Screen
 * readers skip it, as the Content's title is always beside it.
 */
export function Poster({path, width}: {path: string | null; width: number}) {
  return (
    <View
      className="aspect-2/3 overflow-hidden rounded-md bg-accent"
      style={{width}}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      {path !== null && (
        <Image
          source={posterUrl(path, width)}
          style={{flex: 1}}
          contentFit="cover"
          transition={150}
        />
      )}
    </View>
  );
}
