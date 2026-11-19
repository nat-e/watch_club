/**
 * Content search: the Movies and TV Shows, the Sports Events, or the Books, that match what a User
 * types, as both apps show them.
 */
import {infiniteQueryOptions, useInfiniteQuery} from '@tanstack/react-query';
import {type SearchResult, type SearchScope, searchInfiniteOptions} from '@watchclub/api';
import {useCallback, useEffect, useState} from 'react';
import {useTranslation} from 'react-i18next';

/** The pause in typing after which a search starts, in milliseconds */
const TYPING_PAUSE = 300;

/** Every search scope, in the order the apps list them */
export const SEARCH_SCOPES: readonly SearchScope[] = [
  'movies_and_tv_shows',
  'sports_events',
  'books',
];

/** The scope a search starts with */
export const DEFAULT_SEARCH_SCOPE: SearchScope = 'movies_and_tv_shows';

/** Returns whether `value` is a search scope, such as one read from a URL. */
export function isSearchScope(value: unknown): value is SearchScope {
  return SEARCH_SCOPES.some(scope => scope === value);
}

/**
 * Returns the query of a search's results in a scope, loaded page by page, which every screen that
 * shows them shares. It doesn't run for a blank query. A result shows once, though a Metadata
 * Provider can send it again on a later page when its ranking changes in between.
 */
export function searchQuery(query: string, scope: SearchScope) {
  const trimmed = query.trim();
  return infiniteQueryOptions({
    ...searchInfiniteOptions({query: {query: trimmed, scope}}),
    initialPageParam: 1,
    getNextPageParam: lastPage => lastPage.next_page,
    select: data => ({
      results: uniqueResults(data.pages.flatMap(page => page.results)),
      pages: data.pages.length,
    }),
    enabled: trimmed !== '',
  });
}

/** The progress of a search. */
export type SearchStatus =
  /** Nothing to search for, as the query is blank */
  | 'idle'
  | 'loading'
  /** The first page failed to load */
  | 'failed'
  /** The first page loaded, with results or none */
  | 'done';

/** A search, as a screen shows it. */
export interface Search {
  status: SearchStatus;
  /** The results of the pages loaded so far, most relevant first */
  results: SearchResult[];
  /** Whether more pages of results are left to load */
  hasMore: boolean;
  /**
   * The number of pages loaded so far, which grows with each page, even one without new results.
   * Screens that load pages while the end of the list is in view watch it to load the next one
   */
  loadedPages: number;
  /** Loads the next page, unless one is loading. The same function on every render */
  loadMore: () => void;
  /** Loads the first page again, after it failed */
  retry: () => void;
}

/** Returns the search for `query` in `scope`, such as the ones of the search page's URL. */
export function useSearch(query: string, scope: SearchScope): Search {
  const search = useInfiniteQuery(searchQuery(query, scope));
  const {fetchNextPage} = search;
  // Leaves a page that's loading as it is, rather than loading it again
  const loadMore = useCallback(() => {
    void fetchNextPage({cancelRefetch: false});
  }, [fetchNextPage]);
  const status: SearchStatus =
    query.trim() === '' ? 'idle' : search.data ? 'done' : search.isError ? 'failed' : 'loading';
  return {
    status,
    results: search.data?.results ?? [],
    hasMore: search.hasNextPage,
    loadedPages: search.data?.pages ?? 0,
    loadMore,
    retry: () => {
      void search.refetch();
    },
  };
}

/** Returns the name of each search scope in the app's language, such as "Books". */
export function useSearchScopeNames(): Record<SearchScope, string> {
  const {t} = useTranslation('core');
  return {
    // biome-ignore-start lint/style/useNamingConvention: the API's search scopes are snake_case
    movies_and_tv_shows: t($ => $.core.search.scopes.moviesAndTvShows),
    sports_events: t($ => $.core.search.scopes.sportsEvents),
    books: t($ => $.core.search.scopes.books),
    // biome-ignore-end lint/style/useNamingConvention: the API's search scopes are snake_case
  };
}

/**
 * Returns the hint a search in `scope` shows before the User types, in the app's language.
 */
export function useSearchHint(scope: SearchScope): string {
  const {t} = useTranslation('core');
  switch (scope) {
    case 'movies_and_tv_shows':
      return t($ => $.core.search.hint, {context: 'moviesAndTvShows'});
    case 'sports_events':
      return t($ => $.core.search.hint, {context: 'sportsEvents'});
    case 'books':
      return t($ => $.core.search.hint, {context: 'books'});
  }
}

/**
 * Returns the facts a search result shows after its Content Type, when it has them: a Sports
 * Event's date, or the year of other Content, then a Sports Event's league, then the creators.
 * Dates are written as `language`, such as `fr-FR`, writes them.
 */
export function searchResultDetails(result: SearchResult, language: string): string[] {
  const details: string[] = [];
  if (result.date !== null) {
    details.push(formatDate(result.date, language));
  } else if (result.year !== null) {
    details.push(String(result.year));
  }
  if (result.league !== null) {
    details.push(result.league);
  }
  if (result.creators.length > 0) {
    details.push(result.creators.join(', '));
  }
  return details;
}

/**
 * Returns the text a User types into a search field, once they pause, so that a search doesn't
 * start on every key.
 */
export function useTypedQuery(text: string): string {
  const [query, setQuery] = useState(text);
  useEffect(() => {
    const timeout = setTimeout(() => {
      setQuery(text);
    }, TYPING_PAUSE);
    return () => {
      clearTimeout(timeout);
    };
  }, [text]);
  return query;
}

/** Returns a day, such as `2024-09-15`, as `language` writes it, such as "Sep 15, 2024". */
function formatDate(date: string, language: string): string {
  // A date and time without a time zone is in the device's, which formats it, so the day stays
  const midnight = new Date(`${date}T00:00`);
  return midnight.toLocaleDateString(language, {year: 'numeric', month: 'short', day: 'numeric'});
}

/** Returns the results without the ones already listed. */
function uniqueResults(results: SearchResult[]): SearchResult[] {
  const seen = new Set<string>();
  return results.filter(result => {
    const key = `${result.content_type}/${result.external_id}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}
