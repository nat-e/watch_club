import type {Image} from '@watchclub/api';
import {View} from 'react-native';
import {SizedImage} from '@/components/contents/sized-image';

/**
 * A Content's poster, `width` points wide, or a placeholder when it has none. Screen readers skip
 * it, as the Content's title is always beside it.
 */
export function Poster({image, width}: {image: Image | null; width: number}) {
  return (
    <View
      className="aspect-2/3 overflow-hidden rounded-lg bg-accent"
      style={{width}}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      {image !== null && <SizedImage image={image} style={{flex: 1}} />}
    </View>
  );
}
