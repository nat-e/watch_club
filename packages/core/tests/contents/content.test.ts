import {describe, expect, it} from 'vitest';
import {posterUrl} from '../../src/contents/content';

describe('posterUrl', () => {
  it('picks the smallest size that stays sharp at 3 pixels per point', () => {
    expect(posterUrl('/poster.jpg', 48)).toBe('https://image.tmdb.org/t/p/w154/poster.jpg');
    expect(posterUrl('/poster.jpg', 52)).toBe('https://image.tmdb.org/t/p/w185/poster.jpg');
  });

  it('picks the original past the largest size', () => {
    expect(posterUrl('/poster.jpg', 300)).toBe('https://image.tmdb.org/t/p/original/poster.jpg');
  });
});
