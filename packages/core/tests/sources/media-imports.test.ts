import type {MediaImport, Source} from '@watchclub/api';
import {describe, expect, it} from 'vitest';
import {durationSeconds, importsFiles, summarizeFiles} from '../../src/sources/media-imports';

/** A completed import of 5 files, which took 75 seconds. */
const COMPLETED: MediaImport = {
  id: '01a1f26b-170d-75e6-b05d-1b3ceacf37a0',
  trigger: 'manual',
  // biome-ignore-start lint/style/useNamingConvention: the API's fields are snake_case
  files_to_import: 'all',
  state: 'completed',
  failure: null,
  file_count: 5,
  matched_file_count: 3,
  unmatched_file_count: 1,
  failed_file_count: 1,
  removed_file_count: 2,
  started_at: '2026-11-20T10:00:00Z',
  finished_at: '2026-11-20T10:01:15Z',
  // biome-ignore-end lint/style/useNamingConvention: the API's fields are snake_case
};

describe('importsFiles', () => {
  it('is true for Radarr Sources only', () => {
    const radarr: Source = {
      type: 'radarr',
      id: '01a1f26b-170d-75e6-b05d-1b3ceacf37a1',
      // biome-ignore-start lint/style/useNamingConvention: the API's fields are snake_case
      media_type: 'movie',
      url: 'http://radarr:7878/',
      quality_profile: {id: 4, name: 'HD-1080p'},
      root_folder_path: '/movies',
      local_root_folder_path: null,
      // biome-ignore-end lint/style/useNamingConvention: the API's fields are snake_case
    };
    // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
    const sonarr: Source = {...radarr, type: 'sonarr', media_type: 'tv_show_episode'};

    expect(importsFiles(radarr)).toBe(true);
    expect(importsFiles(sonarr)).toBe(false);
  });
});

describe('summarizeFiles', () => {
  it('lists the outcomes with files, in order', () => {
    expect(summarizeFiles(COMPLETED)).toEqual({
      isListing: false,
      isEmpty: false,
      progress: null,
      outcomes: [
        {outcome: 'matched', count: 3},
        {outcome: 'unmatched', count: 1},
        {outcome: 'failed', count: 1},
        {outcome: 'removed', count: 2},
      ],
    });
  });

  it('shows the progress of a running import, out of the files it handles', () => {
    const running: MediaImport = {
      ...COMPLETED,
      state: 'running',
      // biome-ignore-start lint/style/useNamingConvention: the API's fields are snake_case
      failed_file_count: 0,
      removed_file_count: 0,
      finished_at: null,
      // biome-ignore-end lint/style/useNamingConvention: the API's fields are snake_case
    };

    expect(summarizeFiles(running).progress).toEqual({handled: 4, total: 5});
  });

  it('says when the Source is still listing the files', () => {
    // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
    const waiting: MediaImport = {...COMPLETED, state: 'waiting', file_count: null};

    expect(summarizeFiles(waiting).isListing).toBe(true);
    expect(summarizeFiles(waiting).progress).toBeNull();
  });

  it('says when the import had no file to handle or remove', () => {
    const empty: MediaImport = {
      ...COMPLETED,
      // biome-ignore-start lint/style/useNamingConvention: the API's fields are snake_case
      file_count: 0,
      matched_file_count: 0,
      unmatched_file_count: 0,
      failed_file_count: 0,
      removed_file_count: 0,
      // biome-ignore-end lint/style/useNamingConvention: the API's fields are snake_case
    };

    expect(summarizeFiles(empty).isEmpty).toBe(true);
    // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
    expect(summarizeFiles({...empty, removed_file_count: 1}).isEmpty).toBe(false);
  });
});

describe('durationSeconds', () => {
  it('is the time from start to finish', () => {
    expect(durationSeconds(COMPLETED)).toBe(75);
  });

  it('is null while the import is going', () => {
    // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
    expect(durationSeconds({...COMPLETED, state: 'running', finished_at: null})).toBeNull();
  });
});
