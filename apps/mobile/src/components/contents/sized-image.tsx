import type {Image} from '@watchclub/api';
import {Image as ExpoImage, type ImageProps} from 'expo-image';

/**
 * A picture in the sizes its Metadata Provider has, of which Expo Image downloads the size closest
 * to what the screen shows.
 */
export function SizedImage({image, style}: {image: Image; style: ImageProps['style']}) {
  return (
    <ExpoImage
      source={image.map(source => ({uri: source.url, width: source.width, height: source.height}))}
      style={style}
      contentFit="cover"
      transition={150}
    />
  );
}
