import {InfiniteQueryObserver} from '@tanstack/react-query';
import {client, type SearchResult, type SearchResults} from '@watchclub/api';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {searchQuery} from '../../src/contents/search';
import {createQueryClient} from '../../src/query-client';

client.setConfig({baseUrl: 'https://watchclub.example.com'});

/** Returns a search result for the Movie with this TMDB ID. */
function movie(tmdbId: number): SearchResult {
  return {
    // biome-ignore-start lint/style/useNamingConvention: the API uses snake_case field names
    content_type: 'movie',
    tmdb_id: tmdbId,
    title: `Movie ${tmdbId}`,
    year: 2001,
    overview: null,
    poster_path: null,
    // biome-ignore-end lint/style/useNamingConvention: the API uses snake_case field names
  };
}

/** Answers each search with the page of its `page` parameter, and returns the URLs it got. */
function answerPages(pages: Record<string, SearchResults>): URL[] {
  const urls: URL[] = [];
  vi.stubGlobal('fetch', (request: Request) => {
    const url = new URL(request.url);
    urls.push(url);
    return Promise.resolve(Response.json(pages[url.searchParams.get('page') ?? '']));
  });
  return urls;
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('searchQuery', () => {
  it('loads the pages of the trimmed query, and lists each result once', async () => {
    // biome-ignore-start lint/style/useNamingConvention: the API uses snake_case field names
    const urls = answerPages({
      '1': {results: [movie(1), movie(2)], next_page: 2},
      '2': {results: [movie(2), movie(3)], next_page: null},
    });
    // biome-ignore-end lint/style/useNamingConvention: the API uses snake_case field names
    const observer = new InfiniteQueryObserver(createQueryClient(), searchQuery(' amélie '));
    const unsubscribe = observer.subscribe(() => undefined);

    await vi.waitFor(() => {
      expect(observer.getCurrentResult().data).toEqual({results: [movie(1), movie(2)], pages: 1});
    });
    await observer.fetchNextPage();

    const result = observer.getCurrentResult();
    expect(result.data).toEqual({results: [movie(1), movie(2), movie(3)], pages: 2});
    expect(result.hasNextPage).toBe(false);
    expect(urls.map(url => url.searchParams.get('query'))).toEqual(['amélie', 'amélie']);
    unsubscribe();
  });

  it("doesn't search for a blank query", () => {
    expect(searchQuery('  ').enabled).toBe(false);
  });
});
