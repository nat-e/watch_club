/**
 * Content search: the Movies and TV Shows whose title matches what a User types, as both apps show
 * them.
 */
import {infiniteQueryOptions, useInfiniteQuery} from '@tanstack/react-query';
import {type SearchResult, searchInfiniteOptions} from '@watchclub/api';
import {useCallback, useEffect, useState} from 'react';

/** The pause in typing after which a search starts, in milliseconds */
const TYPING_PAUSE = 300;

/**
 * Returns the query of a search's results, loaded page by page, which every screen that shows them
 * shares. It doesn't run for a blank query. A result shows once, though TMDB can send it again on a
 * later page when its ranking changes in between.
 */
export function searchQuery(query: string) {
  const trimmed = query.trim();
  return infiniteQueryOptions({
    ...searchInfiniteOptions({query: {query: trimmed}}),
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

/** Returns the search for `query`, such as the one of the search page's URL. */
export function useSearch(query: string): Search {
  const search = useInfiniteQuery(searchQuery(query));
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

/** Returns the results without the ones already listed. */
function uniqueResults(results: SearchResult[]): SearchResult[] {
  const seen = new Set<string>();
  return results.filter(result => {
    const key = `${result.content_type}/${result.tmdb_id}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}
