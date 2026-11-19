import {InfiniteQueryObserver} from '@tanstack/react-query';
import {client, type SearchResult, type SearchResults} from '@watchclub/api';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {searchQuery, searchResultDetails} from '../../src/contents/search';
import {createQueryClient} from '../../src/query-client';

client.setConfig({baseUrl: 'https://watchclub.example.com'});

/** Returns a search result for the Movie with this External ID. */
function movie(externalId: number): SearchResult {
  return {
    // biome-ignore-start lint/style/useNamingConvention: the API uses snake_case field names
    content_type: 'movie',
    external_id: String(externalId),
    title: `Movie ${externalId}`,
    date: '2001-04-25',
    overview: null,
    poster: null,
    creators: [],
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
    const observer = new InfiniteQueryObserver(
      createQueryClient(),
      searchQuery(' amélie ', 'books'),
    );
    const unsubscribe = observer.subscribe(() => undefined);

    await vi.waitFor(() => {
      expect(observer.getCurrentResult().data).toEqual({results: [movie(1), movie(2)], pages: 1});
    });
    await observer.fetchNextPage();

    const result = observer.getCurrentResult();
    expect(result.data).toEqual({results: [movie(1), movie(2), movie(3)], pages: 2});
    expect(result.hasNextPage).toBe(false);
    expect(urls.map(url => url.searchParams.get('query'))).toEqual(['amélie', 'amélie']);
    expect(urls.map(url => url.searchParams.get('scope'))).toEqual(['books', 'books']);
    unsubscribe();
  });

  it("doesn't search for a blank query", () => {
    expect(searchQuery('  ', 'books').enabled).toBe(false);
  });
});

describe('searchResultDetails', () => {
  it('gives the year, then the creators', () => {
    const book: SearchResult = {
      ...movie(1),
      // biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
      content_type: 'book',
      date: '1961-01-01',
      creators: ['René Goscinny', 'Albert Uderzo'],
    };

    expect(searchResultDetails(book, 'en-US')).toEqual(['1961', 'René Goscinny, Albert Uderzo']);
  });

  it("gives a Sports Event's day in the language, then its league", () => {
    const sportsEvent: SearchResult = {
      ...movie(1),
      // biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
      content_type: 'sports_event',
      date: '2024-09-15',
      creators: ['Boxing'],
    };

    expect(searchResultDetails(sportsEvent, 'en-US')).toEqual(['Sep 15, 2024', 'Boxing']);
    expect(searchResultDetails(sportsEvent, 'fr-FR')).toEqual(['15 sept. 2024', 'Boxing']);
  });

  it('leaves out what the result lacks', () => {
    expect(searchResultDetails({...movie(1), date: null}, 'en-US')).toEqual([]);
  });
});
