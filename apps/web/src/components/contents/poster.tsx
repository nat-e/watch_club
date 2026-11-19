import type {Image} from '@watchclub/api';
import {cn} from 'cn';
import {ImageIcon} from 'lucide-react';
import {SizedImage} from '@/components/contents/sized-image';

/**
 * A Content's poster, or a placeholder when it has none. `className` sets its width, and `width`
 * says the widest it shows, in pixels, for the browser to download the smallest size that stays
 * sharp.
 */
export function Poster({
  image,
  width,
  className,
}: {
  image: Image | null;
  width: number;
  className: string;
}) {
  return (
    <div
      className={cn(
        'relative flex aspect-2/3 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-accent text-subtle-foreground',
        className,
      )}
    >
      {image ? (
        <SizedImage
          image={image}
          width={width}
          className="absolute inset-0 size-full object-cover"
        />
      ) : (
        <ImageIcon className="size-1/3" />
      )}
    </div>
  );
}
