import type {Image} from '@watchclub/api';

/**
 * A picture in the sizes its Metadata Provider has, of which the browser downloads the smallest
 * that stays sharp at `width` pixels wide. Its text alternative is empty, as the pictures of
 * Content and people are beside their name.
 */
export function SizedImage({
  image,
  width,
  className,
}: {
  image: Image;
  /** The widest it shows, in pixels, or `full` when it's as wide as the window */
  width: number | 'full';
  className?: string;
}) {
  return (
    <img
      src={image[0]?.url}
      srcSet={image.map(source => `${source.url} ${source.width}w`).join(', ')}
      sizes={width === 'full' ? '100vw' : `${width}px`}
      alt=""
      loading="lazy"
      className={className}
    />
  );
}
