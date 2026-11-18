import type {ContentType, SearchResult} from '@watchclub/api';
import {useContentTypeNames} from '@watchclub/core/contents/content';
import type {SearchStatus as Status} from '@watchclub/core/contents/search';
import {
  FilmIcon,
  LibraryIcon,
  type LucideIcon,
  SearchXIcon,
  TriangleAlertIcon,
  TvIcon,
} from 'lucide-react';
import {useTranslation} from 'react-i18next';
import {Poster} from '@/components/contents/poster';
import {Button} from '@/components/ui/button';
import {Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle} from '@/components/ui/empty';
import {Skeleton} from '@/components/ui/skeleton';
import {Toggle} from '@/components/ui/toggle';

// biome-ignore lint/style/useNamingConvention: the API's Content Types are snake_case
const CONTENT_TYPE_ICONS: Record<ContentType, LucideIcon> = {movie: FilmIcon, tv_show: TvIcon};

/**
 * A search result's poster, title, type and year, and its overview with `overview`, for a row to
 * wrap.
 */
export function SearchResultSummary({
  result,
  overview = false,
}: {
  result: SearchResult;
  overview?: boolean;
}) {
  const contentTypeNames = useContentTypeNames();
  const Icon = CONTENT_TYPE_ICONS[result.content_type];
  return (
    <>
      <Poster path={result.poster_path} width={overview ? 64 : 48} />
      <span className="flex min-w-0 flex-1 flex-col gap-1">
        <span className="truncate font-semibold">{result.title}</span>
        <span className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-muted-foreground">
          <span className="inline-flex items-center gap-1">
            <Icon className="size-4 text-subtle-foreground" />
            {contentTypeNames[result.content_type]}
          </span>
          {result.year !== null && (
            <>
              {/* i18next-instrument-ignore: a separator, the same in every language */}
              <span aria-hidden="true">·</span>
              <span>{result.year}</span>
            </>
          )}
        </span>
        {overview && result.overview && (
          <span className="line-clamp-2 max-w-readable text-sm text-subtle-foreground">
            {result.overview}
          </span>
        )}
      </span>
    </>
  );
}

/**
 * The hint before typing, loading rows, error or no results that a search shows in place of its
 * results, and nothing once it has results. It also tells screen readers how the search went, as
 * they can't see the results change.
 */
export function SearchStatus({
  status,
  query,
  count,
  retry,
}: {
  status: Status;
  query: string;
  /** The number of results shown */
  count: number;
  retry: () => void;
}) {
  const {t} = useTranslation('core');
  return (
    <>
      <p role="status" className="sr-only">
        {status === 'loading' && t($ => $.core.search.searching)}
        {status === 'failed' && t($ => $.core.search.failed)}
        {status === 'done' && t($ => $.core.search.resultCount, {count})}
      </p>
      <StatusBody status={status} query={query} count={count} retry={retry} />
    </>
  );
}

function StatusBody({
  status,
  query,
  count,
  retry,
}: {
  status: Status;
  query: string;
  count: number;
  retry: () => void;
}) {
  const {t} = useTranslation('core');
  switch (status) {
    case 'idle':
      return (
        <p className="p-6 text-center text-sm text-balance text-muted-foreground">
          {t($ => $.core.search.hint)}
        </p>
      );
    case 'loading':
      return (
        <div className="flex flex-col" aria-hidden="true">
          {[0, 1, 2, 3].map(row => (
            <div key={row} className="flex items-center gap-4 p-2">
              <Skeleton className="aspect-2/3 w-12 rounded-sm" />
              <span className="flex flex-1 flex-col gap-2">
                <Skeleton className="h-3 w-1/2 rounded-full" />
                <Skeleton className="h-3 w-1/4 rounded-full" />
              </span>
            </div>
          ))}
        </div>
      );
    case 'failed':
      return (
        <Empty className="p-6">
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <TriangleAlertIcon />
            </EmptyMedia>
            <EmptyDescription>{t($ => $.core.search.failed)}</EmptyDescription>
          </EmptyHeader>
          <Button variant="secondary" size="sm" onClick={retry}>
            {t($ => $.core.controls.tryAgain)}
          </Button>
        </Empty>
      );
    case 'done':
      return count === 0 ? (
        <Empty className="p-6">
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <SearchXIcon />
            </EmptyMedia>
            <EmptyTitle>{t($ => $.core.search.noResults)}</EmptyTitle>
            <EmptyDescription>{t($ => $.core.search.nothingFound, {query})}</EmptyDescription>
          </EmptyHeader>
        </Empty>
      ) : null;
  }
}

/** The filter that keeps only the Library's Content, disabled until search covers the Library. */
export function InLibraryFilter() {
  const {t} = useTranslation('web');
  return (
    <Toggle variant="outline" size="sm" disabled>
      <LibraryIcon />
      {t($ => $.web.search.inLibrary)}
    </Toggle>
  );
}
