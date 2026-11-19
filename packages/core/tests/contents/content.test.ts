import {describe, expect, it} from 'vitest';
import {formatRating, initials, longDate, tmdbUrl} from '../../src/contents/content';

describe('formatRating', () => {
  it('writes the rating to one decimal, as the language does', () => {
    expect(formatRating(8, 'en-US')).toBe('8.0');
    expect(formatRating(7.9, 'fr-FR')).toBe('7,9');
  });
});

describe('longDate', () => {
  it('writes the day in full, as the language does', () => {
    expect(longDate('2024-09-15', 'en-US')).toBe('September 15, 2024');
    expect(longDate('2024-09-15', 'fr-FR')).toBe('15 septembre 2024');
  });
});

describe('initials', () => {
  it('takes the first letter of the first two words', () => {
    expect(initials('Jean-Pierre Jeunet')).toBe('JJ');
    expect(initials(' Rufus ')).toBe('R');
    expect(initials('Helena Bonham Carter')).toBe('HB');
  });
});

describe('tmdbUrl', () => {
  it('links to the Movie or TV Show on TMDB', () => {
    // biome-ignore-start lint/style/useNamingConvention: the API's fields are snake_case
    expect(tmdbUrl({content_type: 'movie', external_id: '194'})).toBe(
      'https://www.themoviedb.org/movie/194',
    );
    expect(tmdbUrl({content_type: 'tv_show', external_id: '1396'})).toBe(
      'https://www.themoviedb.org/tv/1396',
    );
    expect(tmdbUrl({content_type: 'book', external_id: '442623'})).toBeNull();
    // biome-ignore-end lint/style/useNamingConvention: the API's fields are snake_case
  });
});
