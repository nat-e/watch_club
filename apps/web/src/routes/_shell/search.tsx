import {createFileRoute, Link, stripSearchParams} from '@tanstack/react-router';
import type {SearchScope} from '@watchclub/api';
import {
  DEFAULT_SEARCH_SCOPE,
  isSearchScope,
  type Search,
  useSearch,
} from '@watchclub/core/contents/search';
import {useEffect, useRef, useState} from 'react';
import {useTranslation} from 'react-i18next';
import {contentLink} from '@/components/contents/content-page';
import {SearchField} from '@/components/contents/search-field';
import {
  SearchResultSummary,
  SearchScopes,
  SearchStatus,
} from '@/components/contents/search-results';
import {Page} from '@/components/layouts/page';

/**
 * Every result of a search in a scope, which loads more as the User scrolls. The search field opens
 * it, and stays in the bar to search again. The URL leaves out the default scope.
 */
export const Route = createFileRoute('/_shell/search')({
  validateSearch: (search: Record<string, unknown>): {query: string; scope: SearchScope} => ({
    query: typeof search.query === 'string' ? search.query.trim() : '',
    scope: isSearchScope(search.scope) ? search.scope : DEFAULT_SEARCH_SCOPE,
  }),
  search: {middlewares: [stripSearchParams({scope: DEFAULT_SEARCH_SCOPE})]},
  component: SearchPage,
});

function SearchPage() {
  const {t} = useTranslation('core');
  const {query, scope} = Route.useSearch();
  const navigate = Route.useNavigate();
  const search = useSearch(query, scope);

  return (
    <Page title={t($ => $.core.search.search)} actions={<SearchField />}>
      <div className="flex">
        <SearchScopes
          scope={scope}
          onScopeChange={newScope => {
            void navigate({search: {query, scope: newScope}, replace: true});
          }}
        />
      </div>
      <div>
        <SearchStatus
          status={search.status}
          scope={scope}
          query={query}
          count={search.results.length}
          retry={search.retry}
        />
        <ul className="flex flex-col gap-1">
          {search.results.map(result => (
            <li key={`${result.content_type}/${result.external_id}`}>
              <Link
                {...contentLink(result)}
                className="flex items-center gap-4 rounded-md p-2 transition-colors hover:bg-accent focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-ring"
              >
                <SearchResultSummary result={result} overview />
              </Link>
            </li>
          ))}
        </ul>
        {/* Anew for each search, whose first pages load as the previous one's did */}
        {search.hasMore && <LoadMore key={`${scope}/${query}`} search={search} />}
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

  const {loadMore, loadedPages} = search;
  // Again after each page, as the end may still be in view, but not after a failure: the same
  // number of pages stays loaded until the end scrolls back into view
  useEffect(() => {
    if (isVisible && loadedPages > 0) {
      loadMore();
    }
  }, [isVisible, loadMore, loadedPages]);

  return <div ref={ref} />;
}
