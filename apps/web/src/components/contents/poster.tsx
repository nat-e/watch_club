import type {Image} from '@watchclub/api';
import {cn} from 'cn';
import {ImageIcon} from 'lucide-react';

/**
 * A Content's poster, `width` pixels wide, or a placeholder when it has none. The browser downloads
 * the smallest size that stays sharp on the screen. Its text alternative is empty, as the Content's
 * title is always beside it.
 */
export function Poster({
  image,
  width,
  className,
}: {
  image: Image | null;
  width: number;
  className?: string;
}) {
  return (
    <div
      className={cn(
        'relative flex aspect-2/3 shrink-0 items-center justify-center overflow-hidden rounded-sm bg-accent text-subtle-foreground',
        className,
      )}
      style={{width}}
    >
      {image ? (
        <img
          src={image[0]?.url}
          srcSet={image.map(source => `${source.url} ${source.width}w`).join(', ')}
          sizes={`${width}px`}
          alt=""
          loading="lazy"
          className="absolute inset-0 size-full object-cover"
        />
      ) : (
        <ImageIcon className="size-1/3" />
      )}
    </div>
  );
}
