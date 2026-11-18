import {posterUrl} from '@watchclub/core/contents/content';
import {cn} from 'cn';
import {ImageIcon} from 'lucide-react';

/**
 * A Content's poster from TMDB, `width` pixels wide, or a placeholder when it has none. Its text
 * alternative is empty, as the Content's title is always beside it.
 */
export function Poster({
  path,
  width,
  className,
}: {
  path: string | null;
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
      {path ? (
        <img
          src={posterUrl(path, width)}
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
