import type {Media} from '@watchclub/api';
import {describe, expect, it} from 'vitest';
import {episodeCode, groupMedia} from '../../src/contents/media';

/** Returns a TV Show Episode of this season and number, and nothing else. */
function episode(season: number | null, numberInGroup: number | null): Media {
  return {
    // biome-ignore-start lint/style/useNamingConvention: the API's fields are snake_case
    id: `${season}-${numberInGroup}`,
    group_number: season,
    number_in_group: numberInGroup,
    title: null,
    overview: null,
    image: null,
    release_date: null,
    runtime_seconds: null,
    // biome-ignore-end lint/style/useNamingConvention: the API's fields are snake_case
  };
}

describe('groupMedia', () => {
  it('groups the Media by season, in order', () => {
    const groups = groupMedia([episode(1, 1), episode(1, 2), episode(2, 1)]);

    expect(groups.map(group => [group.number, group.media.map(media => media.id)])).toEqual([
      [1, ['1-1', '1-2']],
      [2, ['2-1']],
    ]);
  });

  it('leaves out the Media without a group, such as a Movie', () => {
    expect(groupMedia([episode(null, null)])).toEqual([]);
  });
});

describe('episodeCode', () => {
  it('writes the season and number on two digits', () => {
    expect(episodeCode(episode(1, 2))).toBe('S01E02');
    expect(episodeCode(episode(12, 105))).toBe('S12E105');
  });
});
