import {createFileRoute, Link} from '@tanstack/react-router';
import {type Search, useSearch} from '@watchclub/core/contents/search';
import {useEffect, useRef, useState} from 'react';
import {useTranslation} from 'react-i18next';
import {contentLink} from '@/components/contents/content-page';
import {
  InLibraryFilter,
  SearchResultSummary,
  SearchStatus,
} from '@/components/contents/search-results';
import {Page} from '@/components/layouts/page';

/**
 * Every result of a search, which loads more as the User scrolls. The search field opens it, and
 * stays in the bar to search again.
 */
export const Route = createFileRoute('/_shell/search')({
  validateSearch: (search: Record<string, unknown>): {query: string} => ({
    query: typeof search.query === 'string' ? search.query.trim() : '',
  }),
  component: SearchPage,
});

function SearchPage() {
  const {t} = useTranslation('core');
  const {query} = Route.useSearch();
  const search = useSearch(query);

  return (
    <Page title={t($ => $.core.search.search)} search>
      <div className="flex">
        <InLibraryFilter />
      </div>
      <div>
        <SearchStatus
          status={search.status}
          query={query}
          count={search.results.length}
          retry={search.retry}
        />
        <ul className="flex flex-col gap-1">
          {search.results.map(result => (
            <li key={`${result.content_type}/${result.tmdb_id}`}>
              <Link
                {...contentLink(result)}
                className="flex items-center gap-4 rounded-md p-2 transition-colors hover:bg-accent focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-ring"
              >
                <SearchResultSummary result={result} overview />
              </Link>
            </li>
          ))}
        </ul>
        {search.hasMore && <LoadMore search={search} />}
      </div>
    </Page>
  );
}

/**
 * The end of the results, which loads the next page while it's in view. After a failure, it tries
 * again when it scrolls back into view.
 */
function LoadMore({search}: {search: Search}) {
  const ref = useRef<HTMLDivElement>(null);
  const [isVisible, setIsVisible] = useState(false);
  useEffect(() => {
    const element = ref.current;
    if (!element) {
      return;
    }
    // A screen ahead, so the next page is there before the User reaches the end
    const observer = new IntersectionObserver(
      ([entry]) => {
        setIsVisible(entry?.isIntersecting ?? false);
      },
      {rootMargin: '100% 0px'},
    );
    observer.observe(element);
    return () => {
      observer.disconnect();
    };
  }, []);

  const {loadMore, results} = search;
  // Again after each page, as the end may still be in view
  // biome-ignore lint/correctness/useExhaustiveDependencies: each new result moves the end
  useEffect(() => {
    if (isVisible) {
      loadMore();
    }
  }, [isVisible, results.length]);

  return <div ref={ref} />;
}
