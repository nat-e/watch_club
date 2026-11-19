import {Radio} from '@base-ui/react/radio';
import {RadioGroup} from '@base-ui/react/radio-group';
import type {ContentType, SearchResult, SearchScope} from '@watchclub/api';
import {useContentTypeNames} from '@watchclub/core/contents/content';
import {
  SEARCH_SCOPES,
  type SearchStatus as Status,
  searchResultDetails,
  useSearchHint,
  useSearchScopeNames,
} from '@watchclub/core/contents/search';
import {useInstanceName} from '@watchclub/core/instance';
import {cn} from 'cn';
import {
  BookIcon,
  ClapperboardIcon,
  FilmIcon,
  LibraryIcon,
  type LucideIcon,
  SearchXIcon,
  TriangleAlertIcon,
  TvIcon,
} from 'lucide-react';
import {Fragment} from 'react';
import {useTranslation} from 'react-i18next';
import {Poster} from '@/components/contents/poster';
import {Button} from '@/components/ui/button';
import {Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle} from '@/components/ui/empty';
import {Skeleton} from '@/components/ui/skeleton';
import {Toggle, toggleVariants} from '@/components/ui/toggle';

const CONTENT_TYPE_ICONS: Record<ContentType, LucideIcon> = {
  movie: FilmIcon,
  // biome-ignore lint/style/useNamingConvention: the API's Content Types are snake_case
  tv_show: TvIcon,
  book: BookIcon,
};

const SEARCH_SCOPE_ICONS: Record<SearchScope, LucideIcon> = {
  // biome-ignore lint/style/useNamingConvention: the API's search scopes are snake_case
  movies_and_tv_shows: ClapperboardIcon,
  books: BookIcon,
};

/**
 * A search result's poster, title, type, year and creators, and its overview with `overview`, for a
 * row to wrap.
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
      <Poster image={result.poster} width={overview ? 64 : 48} />
      <span className="flex min-w-0 flex-1 flex-col gap-1">
        <span className="truncate font-semibold">{result.title}</span>
        <span className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-muted-foreground">
          <span className="inline-flex items-center gap-1">
            <Icon className="size-4 text-subtle-foreground" />
            {contentTypeNames[result.content_type]}
          </span>
          {searchResultDetails(result).map(detail => (
            <Fragment key={detail}>
              {/* i18next-instrument-ignore: a separator, the same in every language */}
              <span aria-hidden="true">·</span>
              <span>{detail}</span>
            </Fragment>
          ))}
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
  scope,
  query,
  count,
  retry,
}: {
  status: Status;
  scope: SearchScope;
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
      <StatusBody status={status} scope={scope} query={query} count={count} retry={retry} />
    </>
  );
}

/** The hint, loading rows, error or no results that show in place of the results. */
function StatusBody({
  status,
  scope,
  query,
  count,
  retry,
}: {
  status: Status;
  scope: SearchScope;
  query: string;
  count: number;
  retry: () => void;
}) {
  const {t} = useTranslation('core');
  const hint = useSearchHint(scope);
  switch (status) {
    case 'idle':
      return <p className="p-6 text-center text-sm text-balance text-muted-foreground">{hint}</p>;
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

/**
 * The scopes a search can look in, one per Metadata Provider, as their results can't share one
 * list. Then the filter that keeps only the Library's Content.
 */
export function SearchScopes({
  scope,
  onScopeChange,
}: {
  scope: SearchScope;
  onScopeChange: (scope: SearchScope) => void;
}) {
  const {t} = useTranslation('core');
  const scopeNames = useSearchScopeNames();
  return (
    <div className="flex flex-1 flex-wrap items-center gap-2">
      <RadioGroup
        aria-label={t($ => $.core.search.scope)}
        value={scope}
        onValueChange={newScope => {
          onScopeChange(newScope);
        }}
        className="flex items-center gap-2"
      >
        {SEARCH_SCOPES.map(option => {
          const Icon = SEARCH_SCOPE_ICONS[option];
          return (
            // A chip, like the Library filter's toggle beside. `cn` lets the chip's classes
            // replace the toggle's defaults, as `Toggle` does
            <Radio.Root
              key={option}
              value={option}
              className={cn(toggleVariants({variant: 'chip', size: 'sm'}))}
            >
              <Icon />
              {scopeNames[option]}
            </Radio.Root>
          );
        })}
      </RadioGroup>
      <InLibraryFilter />
    </div>
  );
}

/** The filter that keeps only the Library's Content, disabled until search covers the Library. */
function InLibraryFilter() {
  const {t} = useTranslation('web');
  const instanceName = useInstanceName();
  return (
    <Toggle variant="chip" size="sm" disabled className="ml-auto">
      <LibraryIcon />
      {t($ => $.web.search.inLibrary, {name: instanceName})}
    </Toggle>
  );
}
