import type {Image} from '@watchclub/api';
import {Image as ExpoImage} from 'expo-image';
import {View} from 'react-native';

/**
 * A Content's poster, `width` points wide, or a placeholder when it has none. Expo Image downloads
 * the size closest to what the screen shows. Screen readers skip it, as the Content's title is
 * always beside it.
 */
export function Poster({image, width}: {image: Image | null; width: number}) {
  return (
    <View
      className="aspect-2/3 overflow-hidden rounded-md bg-accent"
      style={{width}}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      {image !== null && (
        <ExpoImage
          source={image.map(source => ({
            uri: source.url,
            width: source.width,
            height: source.height,
          }))}
          style={{flex: 1}}
          contentFit="cover"
          transition={150}
        />
      )}
    </View>
  );
}
