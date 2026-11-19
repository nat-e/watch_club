import {cn} from 'cn';
import {ChevronLeftIcon, ChevronRightIcon} from 'lucide-react';
import {type ReactNode, useEffect, useState} from 'react';
import {Button} from '@/components/ui/button';

/**
 * A row of items that scrolls sideways, without a scrollbar, as in the Phoenix app. Each edge
 * fades while there's more to scroll that way. With a mouse, arrows show on hover and scroll by
 * most of the row's width. Keyboard users scroll by moving the focus through the items.
 *
 * The row runs into the page's margins, so the items scroll to the screen's edge, and snap to the
 * margin.
 */
export function ScrollRow({
  variant = 'default',
  list = false,
  className,
  children,
}: {
  /**
   * `chips`: closer items, centered, and smaller arrows, in a row that runs into the left margin
   * only, so it ends before what follows it
   */
  variant?: 'default' | 'chips';
  /** Whether the items are a list's, each in a `li` */
  list?: boolean;
  className?: string;
  children: ReactNode;
}) {
  const [track, setTrack] = useState<HTMLElement | null>(null);
  const {isAtStart, isAtEnd} = useScrollEdges(track);
  const Track = list ? 'ul' : 'div';

  const scroll = (direction: 'previous' | 'next') => {
    if (!track) {
      return;
    }
    const reducesMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    track.scrollBy({
      left: (direction === 'next' ? 1 : -1) * track.clientWidth * 0.8,
      behavior: reducesMotion ? 'auto' : 'smooth',
    });
  };

  return (
    <div className={cn('group/row relative', className)}>
      {/* Its vertical padding keeps the items' focus rings from being cut */}
      <Track
        ref={setTrack}
        className={cn(
          'no-scrollbar -my-2 flex snap-x snap-mandatory scroll-px-page overflow-x-auto py-2 *:shrink-0 *:snap-start',
          '[mask-image:linear-gradient(to_right,transparent,black_var(--fade-start),black_calc(100%_-_var(--fade-end)),transparent)]',
          isAtStart ? '[--fade-start:0px]' : '[--fade-start:4rem]',
          isAtEnd ? '[--fade-end:0px]' : '[--fade-end:4rem]',
          variant === 'default' && '-mx-page gap-4 px-page',
          variant === 'chips' && '-ml-page items-center gap-2 pr-1 pl-page',
        )}
      >
        {children}
      </Track>
      {(['previous', 'next'] as const).map(direction => (
        <div
          key={direction}
          className={cn(
            'pointer-events-none absolute inset-y-0 z-10 hidden items-center opacity-0 transition-opacity duration-150 group-hover/row:pointer-events-auto group-hover/row:opacity-100 pointer-fine:flex',
            direction === 'previous' ? 'left-0' : 'right-0',
            (direction === 'previous' ? isAtStart : isAtEnd) && 'invisible',
          )}
        >
          {/* Mouse only: keyboards move through the items */}
          <Button
            variant="secondary"
            size={variant === 'chips' ? 'icon-sm' : 'icon'}
            tabIndex={-1}
            aria-hidden="true"
            className="rounded-full shadow-overlay"
            onClick={() => {
              scroll(direction);
            }}
          >
            {direction === 'previous' ? <ChevronLeftIcon /> : <ChevronRightIcon />}
          </Button>
        </div>
      ))}
    </div>
  );
}

/** Returns whether the row is scrolled to its start, and to its end, which it is when it fits. */
function useScrollEdges(track: HTMLElement | null): {isAtStart: boolean; isAtEnd: boolean} {
  const [isAtStart, setIsAtStart] = useState(true);
  const [isAtEnd, setIsAtEnd] = useState(true);

  useEffect(() => {
    if (!track) {
      return;
    }
    // A pixel's leeway, as zoomed pages scroll by fractions of a pixel
    const update = () => {
      setIsAtStart(track.scrollLeft <= 1);
      setIsAtEnd(track.scrollLeft + track.clientWidth >= track.scrollWidth - 1);
    };
    update();
    track.addEventListener('scroll', update, {passive: true});
    const resizeObserver = new ResizeObserver(update);
    resizeObserver.observe(track);
    return () => {
      track.removeEventListener('scroll', update);
      resizeObserver.disconnect();
    };
  }, [track]);

  return {isAtStart, isAtEnd};
}
